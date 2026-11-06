using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;
using MindBloom.Infrastructure.Services;
using MindBloom.Messaging.Contracts.Payments;
using Moq;

namespace MindBloom.UnitTests.Payments;

// No host or external connections: GUID-scoped EF InMemory and an intercepting HTTP handler.
public class ReservedAppointmentPriceTests
{
    [Theory]
    [InlineData(50, 70, 5000)]
    [InlineData(70, 50, 7000)]
    [InlineData(50, 50, 5000)]
    [InlineData(50.25, 90, 5025)]
    public async Task New_intent_uses_reserved_price_and_existing_minor_unit_conversion(
        decimal price, decimal hourlyRate, long cents)
    {
        await using var s = await Scenario.CreateAsync(price, hourlyRate);
        var result = await s.CreateAsync();
        var post = Assert.Single(s.Stripe.Posts);
        Assert.Equal(cents.ToString(CultureInfo.InvariantCulture), post.Form["amount"]);
        Assert.Equal("usd", post.Form["currency"]);
        Assert.Equal("33", post.Form["metadata[appointmentId]"]);
        Assert.Equal("1", post.Form["metadata[clientUserId]"]);
        Assert.Equal("11", post.Form["metadata[clientId]"]);
        Assert.Equal("mindbloom-appointment-payment-33-initial", post.Key);
        Assert.Equal(price, result.Amount);
        Assert.Equal("usd", result.Currency);
        Assert.Equal("pi_new", result.PaymentIntentId);
        var payment = await s.Db.Payments.SingleAsync();
        Assert.Equal(price, payment.Amount);
        Assert.Equal(PaymentStatus.Pending, payment.Status);
        Assert.Equal(price, s.Appointment.Price);
        Assert.Equal(hourlyRate, s.Appointment.Therapist.HourlyRate);
        Assert.False(s.Appointment.IsPaid);
        await s.AssertMembershipUnchangedAsync();
        Assert.Empty(s.Outbox.Invocations);
        Assert.Empty(s.Notifications.Invocations);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task Nonpositive_reserved_price_never_falls_back_to_hourly_rate(decimal price)
    {
        await using var s = await Scenario.CreateAsync(price, 70m);
        await Assert.ThrowsAsync<BusinessException>(() => s.CreateAsync());
        Assert.Equal(0, s.Stripe.RequestCount);
        Assert.Empty(await s.Db.Payments.ToListAsync());
        Assert.False(s.Db.ChangeTracker.HasChanges());
    }

    [Theory]
    [InlineData("requires_payment_method")]
    [InlineData("requires_confirmation")]
    [InlineData("requires_action")]
    [InlineData("processing")]
    [InlineData("requires_capture")]
    public async Task Matching_pending_intent_is_reused_without_new_charge(string status)
    {
        await using var s = await Scenario.CreateAsync(50m, 70m);
        await s.AddPaymentAsync(50m);
        s.Stripe.Status = status;
        var before = s.PaymentSnapshot();
        var result = await s.CreateAsync();
        Assert.Equal("pi_old", result.PaymentIntentId);
        Assert.Equal("pi_old_secret_test", result.ClientSecret);
        Assert.Equal(50m, result.Amount);
        s.AssertNoPaymentMutation(before);
        Assert.Equal(1, s.Stripe.RequestCount);
    }

    [Theory]
    [InlineData("requires_payment_method")]
    [InlineData("requires_confirmation")]
    [InlineData("requires_action")]
    [InlineData("processing")]
    [InlineData("requires_capture")]
    [InlineData("canceled")]
    [InlineData("unknown")]
    public async Task Unpaid_pending_mismatch_is_rejected_without_mutation_or_replacement(string status)
    {
        await using var s = await Scenario.CreateAsync(50m, 90m);
        await s.AddPaymentAsync(70m);
        s.Stripe.Status = status;
        var before = s.PaymentSnapshot();
        await Assert.ThrowsAsync<BusinessException>(() => s.CreateAsync());
        s.AssertNoPaymentMutation(before);
        Assert.Equal(1, s.Stripe.RequestCount);
    }

    [Theory]
    [InlineData(PaymentStatus.Pending, 50)]
    [InlineData(PaymentStatus.Failed, 50)]
    [InlineData(PaymentStatus.Pending, 0)]
    [InlineData(PaymentStatus.Pending, -1)]
    public async Task Succeeded_historical_amount_survives_create_confirm_and_repeat(
        PaymentStatus status, decimal price)
    {
        await using var s = await Scenario.CreateAsync(price, 90m);
        await s.AddPaymentAsync(70m, status);
        s.Stripe.Status = "succeeded";
        var before = s.PaymentSnapshot();
        var result = await s.CreateAsync();
        Assert.Equal(70m, result.Amount);
        s.AssertNoPaymentMutation(before);
        s.AllowSuccessfulSideEffects();
        await s.Service.ConfirmPaymentAsync(1, new ConfirmPaymentDto { PaymentIntentId = "pi_old" });
        var paidAt = s.Payment!.PaidAtUtc;
        var calls = s.Stripe.RequestCount;
        await s.Service.ConfirmPaymentAsync(1, new ConfirmPaymentDto { PaymentIntentId = "pi_old" });
        Assert.Equal(calls, s.Stripe.RequestCount);
        Assert.Equal(PaymentStatus.Paid, s.Payment.Status);
        Assert.Equal(70m, s.Payment.Amount);
        Assert.NotNull(paidAt);
        Assert.Equal(paidAt, s.Payment.PaidAtUtc);
        Assert.True(s.Appointment.IsPaid);
        Assert.Single(s.Outbox.Invocations);
        await Assert.ThrowsAsync<BusinessException>(() => s.CreateAsync());
        Assert.Empty(s.Stripe.Posts);
    }

    [Fact]
    public async Task Repeated_create_reuses_intent_and_preserves_initial_key()
    {
        await using var s = await Scenario.CreateAsync(50m, 70m);
        var first = await s.CreateAsync();
        var second = await s.CreateAsync();
        Assert.Equal(first.PaymentIntentId, second.PaymentIntentId);
        Assert.Equal("mindbloom-appointment-payment-33-initial", Assert.Single(s.Stripe.Posts).Key);
        Assert.Single(await s.Db.Payments.ToListAsync());
        Assert.Equal(2, s.Stripe.RequestCount);
    }

    [Theory]
    [InlineData(PaymentStatus.Failed, 70)]
    [InlineData(PaymentStatus.Failed, 50)]
    [InlineData(PaymentStatus.Pending, 50)]
    public async Task Verified_canceled_attempt_allows_reserved_price_retry_with_existing_key(
        PaymentStatus status, decimal oldAmount)
    {
        await using var s = await Scenario.CreateAsync(50m, 90m);
        await s.AddPaymentAsync(oldAmount, status);
        s.Stripe.Status = "canceled";
        await s.CreateAsync();
        var post = Assert.Single(s.Stripe.Posts);
        Assert.Equal("5000", post.Form["amount"]);
        Assert.Equal("mindbloom-appointment-payment-33-after-pi_old", post.Key);
        Assert.Equal(50m, s.Payment!.Amount);
        Assert.Equal("pi_new", s.Payment.StripePaymentIntentId);
        Assert.Equal(PaymentStatus.Pending, s.Payment.Status);
        Assert.Single(await s.Db.Payments.ToListAsync());
    }

    [Theory]
    [InlineData(PaymentStatus.Failed, "processing")]
    [InlineData(PaymentStatus.Failed, "requires_payment_method")]
    [InlineData(PaymentStatus.Failed, "requires_capture")]
    [InlineData(PaymentStatus.Failed, "unknown")]
    [InlineData(PaymentStatus.Pending, "unknown")]
    [InlineData(PaymentStatus.RefundPending, "succeeded")]
    [InlineData(PaymentStatus.RefundFailed, "succeeded")]
    public async Task Unresolved_previous_attempt_never_creates_another_charge(
        PaymentStatus status, string stripeStatus)
    {
        await using var s = await Scenario.CreateAsync(50m, 90m);
        await s.AddPaymentAsync(50m, status);
        s.Stripe.Status = stripeStatus;
        var before = s.PaymentSnapshot();
        await Assert.ThrowsAsync<BusinessException>(() => s.CreateAsync());
        s.AssertNoPaymentMutation(before);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Provider_error_is_controlled_and_preserves_local_state(bool existing)
    {
        await using var s = await Scenario.CreateAsync(50m, 70m);
        if (existing) await s.AddPaymentAsync(50m);
        s.Stripe.ProviderError = true;
        var before = s.PaymentSnapshot();
        await Assert.ThrowsAsync<ExternalProviderException>(() => s.CreateAsync());
        Assert.Equal(before, s.PaymentSnapshot());
        Assert.False(s.Db.ChangeTracker.HasChanges());
        Assert.Equal(existing ? 0 : 1, s.Stripe.Posts.Count);
    }

    [Fact]
    public async Task Failed_retry_cannot_trust_a_different_returned_intent_id()
    {
        await using var s = await Scenario.CreateAsync(50m, 70m);
        await s.AddPaymentAsync(70m, PaymentStatus.Failed);
        s.Stripe.Status = "canceled";
        s.Stripe.Mismatch = "id";
        var before = s.PaymentSnapshot();
        await Assert.ThrowsAsync<BusinessException>(() => s.CreateAsync());
        s.AssertNoPaymentMutation(before);
    }

    [Theory]
    [InlineData("id", "Stripe payment reference does not match.")]
    [InlineData("amount", "Stripe payment amount does not match the expected appointment amount.")]
    [InlineData("currency", "Stripe payment currency does not match the expected currency.")]
    [InlineData("appointment", "Stripe payment is linked to a different appointment.")]
    [InlineData("user", "Stripe payment is linked to a different user.")]
    [InlineData("client", "Stripe payment is linked to a different client profile.")]
    public async Task Confirmation_still_checks_recorded_amount_currency_identity_and_metadata(
        string mismatch, string expectedMessage)
    {
        await using var s = await Scenario.CreateAsync(50m, 90m);
        await s.AddPaymentAsync(70m);
        s.Stripe.Status = "succeeded";
        s.Stripe.Mismatch = mismatch;
        var before = s.PaymentSnapshot();
        var error = await Assert.ThrowsAsync<Exception>(() => s.Service.ConfirmPaymentAsync(
            1, new ConfirmPaymentDto { PaymentIntentId = "pi_old" }));
        Assert.Equal(expectedMessage, error.Message);
        s.AssertNoPaymentMutation(before);
        Assert.False(s.Appointment.IsPaid);
    }

    [Fact]
    public async Task Refund_uses_original_actual_charge_not_reserved_price_or_current_rate()
    {
        await using var s = await Scenario.CreateAsync(50m, 90m);
        await s.AddPaymentAsync(70m, PaymentStatus.Paid);
        s.Appointment.IsPaid = true;
        await s.Db.SaveChangesAsync();
        s.Stripe.Status = "succeeded";
        s.AllowSuccessfulSideEffects();
        await s.Service.RefundAppointmentPaymentAsync(1, 33, "Synthetic cancellation");
        var post = Assert.Single(s.Stripe.Posts);
        Assert.Equal("/v1/refunds", post.Path);
        Assert.Equal("7000", post.Form["amount"]);
        Assert.Equal("pi_old", post.Form["payment_intent"]);
        Assert.Equal("mindbloom-refund-payment-44", post.Key);
        Assert.Equal(70m, s.Payment!.Amount);
        Assert.Equal(PaymentStatus.Refunded, s.Payment.Status);
        Assert.False(s.Appointment.IsPaid);
        await s.AssertMembershipUnchangedAsync();
    }

    private sealed class Scenario : IAsyncDisposable
    {
        public ApplicationDbContext Db { get; }
        public Appointment Appointment { get; }
        public Payment? Payment { get; private set; }
        public FakeStripe Stripe { get; } = new();
        public Mock<IBusinessNotificationService> Notifications { get; } = new(MockBehavior.Strict);
        public Mock<IOutboxWriter> Outbox { get; } = new(MockBehavior.Strict);
        public PaymentService Service { get; }
        private readonly HttpClient http;

        private Scenario(ApplicationDbContext db, Appointment appointment)
        {
            Db = db;
            Appointment = appointment;
            http = new HttpClient(Stripe);
            var factory = new Mock<IHttpClientFactory>(MockBehavior.Strict);
            factory.Setup(x => x.CreateClient("Stripe")).Returns(http);
            var provider = new StripeClientProvider(factory.Object,
                Options.Create(new StripeSettings { SecretKey = "sk_test_unit_tests_only" }),
                Options.Create(new ExternalServiceResilienceOptions { StripeMaxNetworkRetries = 0 }),
                NullLogger<StripeClientProvider>.Instance);
            Service = new PaymentService(db, provider, new StripeVerificationService(provider),
                Notifications.Object, Mock.Of<IIntegrationEventPublisher>(MockBehavior.Strict), Outbox.Object);
        }

        public static async Task<Scenario> CreateAsync(decimal price, decimal rate)
        {
            var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase($"reserved-price-{Guid.NewGuid():N}").Options);
            var appointment = new Appointment
            {
                Id = 33, Client = new Client { Id = 11, User = User(1) },
                Therapist = new Therapist { Id = 22, User = User(2), HourlyRate = rate,
                    Biography = "Synthetic F5-10", Specialization = "Test" },
                Price = price, Status = AppointmentStatus.Accepted, Type = AppointmentType.Online,
                StartUtc = DateTime.UtcNow.AddDays(1), EndUtc = DateTime.UtcNow.AddDays(1).AddHours(1)
            };
            db.Add(appointment);
            db.Add(new MembershipPayment
            {
                Id = 66, Amount = 199.25m, Status = PaymentStatus.Paid,
                Currency = "usd", StripePaymentIntentId = "pi_membership_untouched",
                ClientMembership = new ClientMembership
                {
                    Id = 55, Client = appointment.Client, Therapist = appointment.Therapist,
                    Price = 199.25m, RemainingSessions = 3, TotalSessions = 4, IsActive = true
                }
            });
            await db.SaveChangesAsync();
            return new Scenario(db, appointment);
        }

        private static ApplicationUser User(int id) => new()
        {
            Id = id, FirstName = "Synthetic", LastName = "Test",
            UserName = $"f510-{id}@test.local", Email = $"f510-{id}@test.local", IsActive = true
        };

        public async Task AddPaymentAsync(decimal amount, PaymentStatus status = PaymentStatus.Pending)
        {
            Payment = new Payment { Id = 44, Appointment = Appointment, Amount = amount,
                Status = status, StripePaymentIntentId = "pi_old" };
            Db.Add(Payment);
            await Db.SaveChangesAsync();
            Stripe.Amount = (long)(amount * 100m);
        }

        public Task<PaymentIntentResponseDto> CreateAsync() => Service.CreatePaymentIntentAsync(
            1, new CreatePaymentIntentDto { AppointmentId = 33 });

        public string PaymentSnapshot() => JsonSerializer.Serialize(Db.Payments.AsNoTracking()
            .Select(x => new { x.Id, x.Amount, x.Status, x.StripePaymentIntentId,
                x.PaidAtUtc, x.UpdatedAtUtc, x.RefundedAtUtc, x.StripeRefundId }).ToArray());

        public void AssertNoPaymentMutation(string before)
        {
            Assert.Equal(before, PaymentSnapshot());
            Assert.False(Db.ChangeTracker.HasChanges());
            Assert.Empty(Stripe.Posts);
            Assert.Empty(Outbox.Invocations);
            Assert.Empty(Notifications.Invocations);
        }

        public async Task AssertMembershipUnchangedAsync()
        {
            var membership = await Db.ClientMemberships.AsNoTracking().SingleAsync();
            Assert.Equal(199.25m, membership.Price);
            Assert.Equal(3, membership.RemainingSessions);
            Assert.True(membership.IsActive);
            Assert.Null(membership.UpdatedAtUtc);
            var payment = await Db.MembershipPayments.AsNoTracking().SingleAsync();
            Assert.Equal(199.25m, payment.Amount);
            Assert.Equal("pi_membership_untouched", payment.StripePaymentIntentId);
            Assert.Equal(PaymentStatus.Paid, payment.Status);
            Assert.Null(payment.UpdatedAtUtc);
        }

        public void AllowSuccessfulSideEffects()
        {
            Notifications.Setup(x => x.PublishAsync(It.IsAny<int>(), It.IsAny<string>(),
                It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<NotificationActionType>(),
                It.IsAny<int?>(), It.IsAny<bool>(), It.IsAny<bool>(), It.IsAny<Guid?>(),
                It.IsAny<CancellationToken>())).Returns(Task.CompletedTask);
            Outbox.Setup(x => x.EnqueueAsync(It.IsAny<PaymentSucceededEvent>(), It.IsAny<string>(),
                It.IsAny<CancellationToken>(), It.IsAny<string?>())).Returns(Task.CompletedTask);
            Outbox.Setup(x => x.EnqueueAsync(It.IsAny<PaymentRefundedEvent>(), It.IsAny<string>(),
                It.IsAny<CancellationToken>(), It.IsAny<string?>())).Returns(Task.CompletedTask);
        }

        public async ValueTask DisposeAsync()
        {
            http.Dispose();
            await Db.DisposeAsync();
        }
    }

    private sealed record Post(string Path, Dictionary<string, string> Form, string Key);

    private sealed class FakeStripe : HttpMessageHandler
    {
        public string Status { get; set; } = "requires_payment_method";
        public long Amount { get; set; } = 5000;
        public bool ProviderError { get; set; }
        public string? Mismatch { get; set; }
        public int RequestCount { get; private set; }
        public List<Post> Posts { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestCount++;
            var path = request.RequestUri!.AbsolutePath;
            Dictionary<string, string>? form = null;
            if (request.Method == HttpMethod.Post)
            {
                var body = await request.Content!.ReadAsStringAsync(cancellationToken);
                form = body.Split('&').Select(x => x.Split('=', 2)).ToDictionary(
                    x => WebUtility.UrlDecode(x[0]), x => WebUtility.UrlDecode(x[1]));
                Posts.Add(new Post(path, form, request.Headers.GetValues("Idempotency-Key").Single()));
                Assert.Contains(path, new[] { "/v1/payment_intents", "/v1/refunds" });
            }
            else
            {
                Assert.Equal(HttpMethod.Get, request.Method);
                Assert.Contains(path, new[] { "/v1/payment_intents/pi_old", "/v1/payment_intents/pi_new" });
            }

            if (ProviderError)
            {
                var error = Response(HttpStatusCode.InternalServerError,
                    "{\"error\":{\"type\":\"api_error\",\"message\":\"SYNTHETIC_PROVIDER_ERROR\"}}");
                // Keep this failure/persistence test independent of SDK transport retry defaults.
                error.Headers.Add("Stripe-Should-Retry", "false");
                return error;
            }

            if (path == "/v1/refunds")
                return Response(HttpStatusCode.OK, JsonSerializer.Serialize(new
                {
                    id = "re_test", @object = "refund", status = "succeeded",
                    amount = long.Parse(form!["amount"], CultureInfo.InvariantCulture), payment_intent = "pi_old"
                }));

            var id = path.EndsWith("pi_old", StringComparison.Ordinal) ? "pi_old" : "pi_new";
            if (form != null) Amount = long.Parse(form["amount"], CultureInfo.InvariantCulture);
            return Response(HttpStatusCode.OK, JsonSerializer.Serialize(new
            {
                id = Mismatch == "id" ? "pi_wrong" : id, @object = "payment_intent",
                status = form != null ? "requires_payment_method" : Status,
                client_secret = $"{id}_secret_test", amount = Mismatch == "amount" ? Amount + 1 : Amount,
                amount_received = Amount, currency = Mismatch == "currency" ? "eur" : "usd",
                metadata = new
                {
                    appointmentId = Mismatch == "appointment" ? "999" : "33",
                    clientUserId = Mismatch == "user" ? "999" : "1",
                    clientId = Mismatch == "client" ? "999" : "11"
                }
            }));
        }

        private static HttpResponseMessage Response(HttpStatusCode status, string json) => new(status)
        {
            Content = new StringContent(json, Encoding.UTF8, "application/json")
        };
    }
}
