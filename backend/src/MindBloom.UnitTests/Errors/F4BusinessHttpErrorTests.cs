using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MindBloom.API.Middlewares;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;
using MindBloom.Infrastructure.Services;
using MindBloom.Messaging.Contracts.Payments;
using Moq;

namespace MindBloom.UnitTests.Errors;

// Real services and exception middleware, without an API host, SQL or network.
public sealed class F4BusinessHttpErrorTests
{
    [Theory]
    [InlineData("requires_payment_method")]
    [InlineData("requires_confirmation")]
    [InlineData("requires_action")]
    [InlineData("processing")]
    [InlineData("canceled")]
    public async Task UnconfirmedPayment_Returns409_WithoutConfirmingOrPublishing(string status)
    {
        await using var scenario = await Scenario.CreateAsync();
        using var handler = new StripeHandler(status);
        using var http = new HttpClient(handler);

        var response = await InvokeAsync(() => scenario.PaymentService(http)
            .ConfirmPaymentAsync(1, new ConfirmPaymentDto { PaymentIntentId = "pi_f4_test" }));

        AssertProblem(response, 409, "business_rule_violation",
            "Payment has not been completed. Please check its status before confirming again.");
        Assert.Equal(1, handler.RequestCount);
        await scenario.AssertUnchangedAsync();
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(4)]
    [InlineData(1001)]
    public async Task InvalidCancellationReason_Returns400_WithoutSideEffects(int length)
    {
        await using var scenario = await Scenario.CreateAsync();
        var response = await InvokeAsync(() => scenario.AdminService().CancelAppointmentAsync(
            3, 33, new AdminCancelAppointmentDto { Reason = $"  {new string('x', length)}  " }));

        var message = length == 0 ? "Cancellation reason is required."
            : length < 5 ? "Cancellation reason must contain at least 5 characters."
            : "Cancellation reason may contain at most 1000 characters.";
        AssertProblem(response, 400, "bad_request", message);
        await scenario.AssertUnchangedAsync();
    }

    [Theory]
    [InlineData(AppointmentStatus.Completed)]
    [InlineData(AppointmentStatus.Rejected)]
    public async Task TerminalAppointment_Returns409_WithoutCancellingOrRefunding(AppointmentStatus status)
    {
        await using var scenario = await Scenario.CreateAsync(status);
        var response = await InvokeAsync(() => scenario.AdminService().CancelAppointmentAsync(
            3, 33, new AdminCancelAppointmentDto { Reason = "Administrative cancellation" }));

        AssertProblem(response, 409, "business_rule_violation",
            "A completed or rejected appointment cannot be cancelled.");
        await scenario.AssertUnchangedAsync();
    }

    [Theory]
    [InlineData(AppointmentStatus.Pending, 5)]
    [InlineData(AppointmentStatus.Accepted, 1000)]
    public async Task ValidCancellation_PreservesSuccessfulStatusAndAudit(AppointmentStatus status, int length)
    {
        await using var scenario = await Scenario.CreateAsync(status);
        var reason = new string('x', length);
        scenario.Memberships.Setup(x => x.HandleAppointmentCancellationAsync(33, reason, true))
            .Returns(Task.CompletedTask);

        var response = await InvokeAsync(() => scenario.AdminService().CancelAppointmentAsync(
            3, 33, new AdminCancelAppointmentDto { Reason = $"  {reason}  " }));

        Assert.Equal(204, response.Status);
        Assert.Equal(AppointmentStatus.Cancelled,
            (await scenario.Db.Appointments.AsNoTracking().SingleAsync()).Status);
        var audit = await scenario.Db.AppointmentStatusAudits.AsNoTracking().SingleAsync();
        Assert.Equal(status, audit.PreviousStatus);
        Assert.Equal(AppointmentStatus.Cancelled, audit.NewStatus);
        Assert.Equal(3, audit.ChangedByUserId);
        Assert.Equal(reason, audit.Reason);
        scenario.Memberships.Verify(x => x.HandleAppointmentCancellationAsync(33, reason, true), Times.Once);
        Assert.Empty(scenario.Refunds.Invocations); // Pending payment needs no refund.
    }

    [Fact]
    public async Task SuccessfulPaymentAndRepeatedConfirmation_PreservePaidStateAndSingleEffects()
    {
        await using var scenario = await Scenario.CreateAsync();
        using var handler = new StripeHandler("succeeded");
        using var http = new HttpClient(handler);
        scenario.Outbox.Setup(x => x.EnqueueAsync(It.IsAny<PaymentSucceededEvent>(),
                It.IsAny<string>(), It.IsAny<CancellationToken>(), It.IsAny<string?>()))
            .Returns(Task.CompletedTask);
        scenario.Notifications.Setup(x => x.PublishAsync(It.IsAny<int>(), It.IsAny<string>(),
                It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<NotificationActionType>(),
                It.IsAny<int?>(), It.IsAny<bool>(), It.IsAny<bool>(), It.IsAny<Guid?>(),
                It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);
        var service = scenario.PaymentService(http);
        var request = new ConfirmPaymentDto { PaymentIntentId = "pi_f4_test" };

        Assert.Equal(204, (await InvokeAsync(() => service.ConfirmPaymentAsync(1, request))).Status);
        var paidAt = (await scenario.Db.Payments.AsNoTracking().SingleAsync()).PaidAtUtc;
        Assert.NotNull(paidAt);
        Assert.Equal(204, (await InvokeAsync(() => service.ConfirmPaymentAsync(1, request))).Status);

        var payment = await scenario.Db.Payments.AsNoTracking().SingleAsync();
        Assert.Equal(PaymentStatus.Paid, payment.Status);
        Assert.Equal(paidAt, payment.PaidAtUtc);
        Assert.Equal(50m, payment.Amount);
        Assert.True((await scenario.Db.Appointments.AsNoTracking().SingleAsync()).IsPaid);
        Assert.Equal(1, handler.RequestCount);
        Assert.Single(scenario.Outbox.Invocations);
        Assert.Single(scenario.Notifications.Invocations);
    }

    [Theory]
    [InlineData("id")]
    [InlineData("amount")]
    [InlineData("currency")]
    public async Task IntegrityChecks_RemainSafe500_WithoutConfirmingPayment(string mismatch)
    {
        await using var scenario = await Scenario.CreateAsync();
        using var handler = new StripeHandler("succeeded", mismatch);
        using var http = new HttpClient(handler);
        var response = await InvokeAsync(() => scenario.PaymentService(http)
            .ConfirmPaymentAsync(1, new ConfirmPaymentDto { PaymentIntentId = "pi_f4_test" }));

        AssertProblem(response, 500, "internal_server_error", "An unexpected server error occurred.");
        Assert.DoesNotContain("does not match", response.Json);
        Assert.DoesNotContain("stackTrace", response.Json);
        await scenario.AssertUnchangedAsync();
    }

    [Fact]
    public async Task ProviderFailure_Remains503_WithoutLeakingProviderDetails()
    {
        await using var scenario = await Scenario.CreateAsync();
        using var handler = new StripeHandler("succeeded", "provider");
        using var http = new HttpClient(handler);
        var response = await InvokeAsync(() => scenario.PaymentService(http)
            .ConfirmPaymentAsync(1, new ConfirmPaymentDto { PaymentIntentId = "pi_f4_test" }));

        Assert.Equal(503, response.Status);
        Assert.DoesNotContain("INTERNAL_PROVIDER_DETAIL", response.Json);
        await scenario.AssertUnchangedAsync();
    }

    [Fact]
    public async Task OtherClient_RemainsRejected_BeforeAnyStripeRequest()
    {
        await using var scenario = await Scenario.CreateAsync();
        using var handler = new StripeHandler("succeeded");
        using var http = new HttpClient(handler);
        var response = await InvokeAsync(() => scenario.PaymentService(http)
            .ConfirmPaymentAsync(4, new ConfirmPaymentDto { PaymentIntentId = "pi_f4_test" }));

        AssertProblem(response, 409, "business_rule_violation", "This payment does not belong to you.");
        Assert.Equal(0, handler.RequestCount);
        await scenario.AssertUnchangedAsync();
    }

    [Fact]
    public async Task MissingAdministrator_Remains404_WithoutCancelling()
    {
        await using var scenario = await Scenario.CreateAsync();
        var response = await InvokeAsync(() => scenario.AdminService().CancelAppointmentAsync(
            999, 33, new AdminCancelAppointmentDto { Reason = "Administrative cancellation" }));

        AssertProblem(response, 404, "not_found", "Administrator not found.");
        await scenario.AssertUnchangedAsync();
    }

    private static void AssertProblem((int Status, string Json) response,
        int status, string code, string message)
    {
        Assert.Equal(status, response.Status);
        using var body = JsonDocument.Parse(response.Json);
        Assert.Equal(code, body.RootElement.GetProperty("errorCode").GetString());
        Assert.Equal(message, body.RootElement.GetProperty("detail").GetString());
    }

    private static async Task<(int Status, string Json)> InvokeAsync(Func<Task> action)
    {
        var host = new Mock<IHostEnvironment>();
        host.SetupGet(x => x.EnvironmentName).Returns("Production");
        var context = new DefaultHttpContext();
        await using var body = new MemoryStream();
        context.Response.Body = body;
        var middleware = new GlobalExceptionMiddleware(async http =>
        {
            await action();
            http.Response.StatusCode = StatusCodes.Status204NoContent;
        }, NullLogger<GlobalExceptionMiddleware>.Instance, host.Object);
        await middleware.InvokeAsync(context);
        body.Position = 0;
        using var reader = new StreamReader(body, Encoding.UTF8, leaveOpen: true);
        return (context.Response.StatusCode, await reader.ReadToEndAsync());
    }

    private sealed class Scenario(ApplicationDbContext db, AppointmentStatus status) : IAsyncDisposable
    {
        public ApplicationDbContext Db { get; } = db;
        public Mock<IMembershipService> Memberships { get; } = new(MockBehavior.Strict);
        public Mock<IPaymentService> Refunds { get; } = new(MockBehavior.Strict);
        public Mock<IBusinessNotificationService> Notifications { get; } = new(MockBehavior.Strict);
        public Mock<IOutboxWriter> Outbox { get; } = new(MockBehavior.Strict);

        public static async Task<Scenario> CreateAsync(AppointmentStatus status = AppointmentStatus.Accepted)
        {
            var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase($"f4-business-http-{Guid.NewGuid():N}").Options);
            var appointment = new Appointment
            {
                Id = 33, Client = new Client { Id = 11, User = User(1) },
                Therapist = new Therapist { Id = 22, User = User(2), HourlyRate = 50m,
                    Biography = "Synthetic F4 test", Specialization = "Test" },
                Status = status, Price = 50m, Type = AppointmentType.Online,
                StartUtc = DateTime.UtcNow.AddDays(1), EndUtc = DateTime.UtcNow.AddDays(1).AddHours(1)
            };
            db.AddRange(new Payment { Id = 44, Appointment = appointment, Amount = 50m,
                    Status = PaymentStatus.Pending, StripePaymentIntentId = "pi_f4_test" },
                new Client { Id = 12, User = User(4) }, User(3));
            await db.SaveChangesAsync();
            return new Scenario(db, status);
        }

        private static ApplicationUser User(int id) => new()
        {
            Id = id, FirstName = "F4", LastName = "Test", UserName = $"f4-{id}@test.local",
            Email = $"f4-{id}@test.local", IsActive = true
        };

        public AdminService AdminService() => new(null!, Db, Notifications.Object,
            Refunds.Object, Memberships.Object, Mock.Of<IAuthService>());

        public PaymentService PaymentService(HttpClient http)
        {
            var factory = new Mock<IHttpClientFactory>(MockBehavior.Strict);
            factory.Setup(x => x.CreateClient("Stripe")).Returns(http);
            var provider = new StripeClientProvider(factory.Object,
                Options.Create(new StripeSettings { SecretKey = "sk_test_unit_tests_only" }),
                Options.Create(new ExternalServiceResilienceOptions { StripeMaxNetworkRetries = 0 }),
                NullLogger<StripeClientProvider>.Instance);
            return new PaymentService(Db, provider, new StripeVerificationService(provider),
                Notifications.Object, Mock.Of<IIntegrationEventPublisher>(), Outbox.Object);
        }

        public async Task AssertUnchangedAsync()
        {
            var appointment = await Db.Appointments.AsNoTracking().SingleAsync();
            Assert.Equal(status, appointment.Status);
            Assert.False(appointment.IsPaid);
            Assert.Null(appointment.UpdatedAtUtc);
            var payment = await Db.Payments.AsNoTracking().SingleAsync();
            Assert.Equal(PaymentStatus.Pending, payment.Status);
            Assert.Equal(50m, payment.Amount);
            Assert.Null(payment.PaidAtUtc);
            Assert.Null(payment.UpdatedAtUtc);
            Assert.Empty(await Db.AppointmentStatusAudits.ToListAsync());
            Assert.Empty(await Db.OutboxMessages.ToListAsync());
            Assert.Empty(await Db.Notifications.ToListAsync());
            Assert.False(Db.ChangeTracker.HasChanges());
            Assert.Empty(Memberships.Invocations);
            Assert.Empty(Refunds.Invocations);
            Assert.Empty(Notifications.Invocations);
            Assert.Empty(Outbox.Invocations);
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }

    private sealed class StripeHandler(string status, string? mismatch = null) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.Equal("/v1/payment_intents/pi_f4_test", request.RequestUri!.AbsolutePath);
            RequestCount++;
            var data = new Dictionary<string, object>
            {
                ["id"] = mismatch == "id" ? "pi_other" : "pi_f4_test",
                ["object"] = "payment_intent", ["status"] = status,
                ["amount"] = mismatch == "amount" ? 5100 : 5000,
                ["currency"] = mismatch == "currency" ? "eur" : "usd",
                ["metadata"] = new { appointmentId = "33", clientUserId = "1", clientId = "11" }
            };
            return Task.FromResult(new HttpResponseMessage(mismatch == "provider"
                ? HttpStatusCode.InternalServerError : HttpStatusCode.OK)
            {
                Content = new StringContent(mismatch == "provider"
                    ? "{\"error\":{\"type\":\"api_error\",\"message\":\"INTERNAL_PROVIDER_DETAIL\"}}"
                    : JsonSerializer.Serialize(data), Encoding.UTF8, "application/json")
            });
        }
    }
}
