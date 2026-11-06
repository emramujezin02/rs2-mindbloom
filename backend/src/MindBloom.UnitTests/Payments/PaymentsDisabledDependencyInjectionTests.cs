using System.Net;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using MindBloom.API.Controllers;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Appointments.Validators;
using MindBloom.Application.Features.Auth.Interfaces;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.DependencyInjection;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;
using MindBloom.Shared.Observability;
using Moq;

namespace MindBloom.UnitTests.Payments;

// No host is started. Real infrastructure registrations, GUID EF InMemory,
// mock messaging/auth ports and an intercepting handler; never SQL or Stripe.
public sealed class PaymentsDisabledDependencyInjectionTests
{
    [Fact]
    public async Task Disabled_empty_key_resolves_real_admin_and_appointment_graphs()
    {
        await using var s = new Scenario(false);
        Assert.IsType<MindBloom.Infrastructure.Services.AdminService>(s.Get<IAdminService>());
        Assert.IsType<MindBloom.Infrastructure.Services.AppointmentService>(s.Get<IAppointmentService>());
        Assert.NotNull(s.Get<StripeVerificationService>());
        s.AssertNoExternalAccess();
    }

    [Fact]
    public async Task Disabled_admin_listing_and_verification_details_execute()
    {
        await using var s = new Scenario(false);
        await s.SeedAsync();
        var admin = s.Get<IAdminService>();
        var list = await admin.GetPendingTherapistsAsync(new SearchTherapistVerificationDto());
        Assert.Equal(1, list.TotalCount);
        var details = await admin.GetTherapistVerificationDetailsAsync(22);
        Assert.Equal(22, details.TherapistId);
        s.AssertNoExternalAccess();
    }

    [Fact]
    public async Task Disabled_approval_reaches_actual_missing_document_business_guard()
    {
        await using var s = new Scenario(false);
        await s.SeedAsync();
        var error = await Assert.ThrowsAsync<BusinessException>(() =>
            s.Get<IAdminService>().UpdateTherapistVerificationAsync(3, 22,
                new UpdateTherapistVerificationDto { Status = TherapistVerificationStatus.Approved }));
        Assert.Equal("Therapist cannot be approved without uploaded verification documents.", error.Message);
        Assert.Equal(TherapistVerificationStatus.Pending, (await s.Db.Therapists.SingleAsync()).VerificationStatus);
        Assert.Empty(await s.Db.TherapistVerificationAudits.ToListAsync());
        s.AssertNoExternalAccess();
    }

    [Fact]
    public async Task Disabled_booking_entry_graph_and_real_request_validator_are_available()
    {
        await using var s = new Scenario(false);
        var controller = new AppointmentsController(s.Get<IAppointmentService>());
        Assert.NotNull(controller);
        var validation = await new CreateAppointmentDtoValidator().ValidateAsync(new CreateAppointmentDto
        {
            TherapistId = 0, StartUtc = DateTime.UtcNow.AddDays(1),
            EndUtc = DateTime.UtcNow.AddDays(1).AddHours(1), Type = AppointmentType.Online
        });
        Assert.False(validation.IsValid);
        Assert.Contains(validation.Errors, e => e.PropertyName == nameof(CreateAppointmentDto.TherapistId));
        // The SQL booking lock/transaction is deliberately not simulated by InMemory.
        s.AssertNoExternalAccess();
    }

    [Fact]
    public async Task Disabled_pending_therapist_still_fails_real_booking_eligibility_rule()
    {
        await using var s = new Scenario(false);
        await s.SeedAsync();
        Assert.NotNull(s.Get<IAppointmentService>());
        var therapist = await s.Db.Therapists.Include(t => t.User).SingleAsync();
        var error = Assert.Throws<BusinessException>(() => AppointmentBookingRules.EnsureTherapistEligible(therapist));
        Assert.Equal("This therapist is not available for booking.", error.Message);
        Assert.Empty(await s.Db.Appointments.ToListAsync());
        s.AssertNoExternalAccess();
    }

    [Theory]
    [InlineData("")]
    [InlineData("sk_test_unit_tests_only")]
    public async Task Disabled_client_and_verification_fail_explicitly_even_if_key_exists(string key)
    {
        await using var s = new Scenario(false, key);
        var provider = s.Get<StripeClientProvider>();
        Assert.Equal("Payments are disabled.", Assert.Throws<BusinessException>(() => provider.Client).Message);
        var error = await Assert.ThrowsAsync<BusinessException>(() =>
            s.Get<StripeVerificationService>().GetPaymentIntentAsync("pi_unit"));
        Assert.Equal("Payments are disabled.", error.Message);
        s.AssertNoExternalAccess();
    }

    [Fact]
    public async Task Disabled_actual_payment_creation_never_fabricates_payment_or_calls_http()
    {
        await using var s = new Scenario(false);
        await s.SeedAsync();
        var appointment = new Appointment
        {
            Id = 33, ClientId = 11, TherapistId = 22, Price = 50.25m,
            Status = AppointmentStatus.Accepted, Type = AppointmentType.Online,
            StartUtc = DateTime.UtcNow.AddDays(1), EndUtc = DateTime.UtcNow.AddDays(1).AddHours(1)
        };
        s.Db.Appointments.Add(appointment);
        await s.Db.SaveChangesAsync();
        var error = await Assert.ThrowsAsync<BusinessException>(() =>
            s.Get<IPaymentService>().CreatePaymentIntentAsync(1, new CreatePaymentIntentDto { AppointmentId = 33 }));
        Assert.Equal("Payments are disabled.", error.Message);
        Assert.Empty(await s.Db.Payments.ToListAsync());
        Assert.False(appointment.IsPaid);
        Assert.Equal(50.25m, appointment.Price);
        s.AssertNoExternalAccess();
    }

    [Fact]
    public async Task Enabled_registered_client_is_deferred_cached_and_uses_only_fake_http()
    {
        await using var s = new Scenario(true, "sk_test_unit_tests_only");
        var provider = s.Get<StripeClientProvider>();
        var verification = s.Get<StripeVerificationService>();
        s.Factory.Verify(f => f.CreateClient(It.IsAny<string>()), Times.Never);
        var intent = await verification.GetPaymentIntentAsync("pi_unit");
        Assert.Equal("pi_unit", intent.Id);
        Assert.Equal("usd", intent.Currency);
        Assert.Same(provider.Client, provider.Client);
        Assert.Equal(1, s.Handler.Requests);
        s.Factory.Verify(f => f.CreateClient("Stripe"), Times.Once);
    }

    [Theory]
    [InlineData("", "whsec_unit_tests_only")]
    [InlineData("sk_test_unit_tests_only", "")]
    public async Task Enabled_missing_required_configuration_fails_without_fallback(string key, string webhook)
    {
        await using var s = new Scenario(true, key, webhook);
        Assert.Throws<OptionsValidationException>(() => s.Get<IOptions<StripeSettings>>().Value);
        Assert.Throws<OptionsValidationException>(() => s.Get<StripeClientProvider>());
        s.AssertNoExternalAccess();
    }

    private sealed class Scenario : IAsyncDisposable
    {
        public ApplicationDbContext Db { get; } = new(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase("payments-disabled-" + Guid.NewGuid().ToString("N")).Options);
        public FakeStripeHandler Handler { get; } = new();
        public Mock<IHttpClientFactory> Factory { get; } = new(MockBehavior.Strict);
        private readonly ServiceProvider provider;
        private readonly IServiceScope scope;
        private readonly HttpClient http;

        public Scenario(bool enabled, string key = "", string webhook = "whsec_unit_tests_only")
        {
            var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["DB_CONNECTION"] = "Server=never-connect.invalid;Database=unit_only;Integrated Security=true",
                ["ASPNETCORE_ENVIRONMENT"] = "Testing",
                ["ExternalServices:PaymentsEnabled"] = enabled.ToString(),
                ["ExternalServices:EmailEnabled"] = "false", ["ExternalServices:FirebaseEnabled"] = "false",
                ["STRIPE_SECRET_KEY"] = key, ["STRIPE_WEBHOOK_SECRET"] = webhook,
                ["AccountLockout:MaxFailedAccessAttempts"] = "5", ["AccountLockout:LockoutMinutes"] = "15",
                ["JWT_EXPIRATION_MINUTES"] = "30",
                ["JWT_SECRET"] = new string('q', 64), ["JWT_ISSUER"] = "unit.invalid", ["JWT_AUDIENCE"] = "unit.invalid",
                ["ExternalServiceResilience:StripeMaxNetworkRetries"] = "0"
            }).Build();
            var services = new ServiceCollection();
            services.AddLogging();
            services.AddInfrastructure(config);
            // Override SQL context registration before any context/service resolution.
            services.AddSingleton(Db);
            services.AddSingleton(Mock.Of<IAuthService>(MockBehavior.Strict));
            services.AddSingleton(Mock.Of<IIntegrationEventPublisher>(MockBehavior.Strict));
            services.AddSingleton(Mock.Of<IOutboxWriter>(MockBehavior.Strict));
            services.AddSingleton(Mock.Of<IBusinessNotificationService>(MockBehavior.Strict));
            services.AddSingleton(new ApplicationMetrics());
            http = new HttpClient(Handler);
            Factory.Setup(f => f.CreateClient("Stripe")).Returns(http);
            services.AddSingleton(Factory.Object);
            provider = services.BuildServiceProvider(new ServiceProviderOptions { ValidateScopes = true });
            scope = provider.CreateScope();
        }

        public T Get<T>() where T : notnull => scope.ServiceProvider.GetRequiredService<T>();
        public void AssertNoExternalAccess()
        {
            Factory.Verify(f => f.CreateClient(It.IsAny<string>()), Times.Never);
            Assert.Equal(0, Handler.Requests);
        }
        public async Task SeedAsync()
        {
            static ApplicationUser User(int id) => new()
            {
                Id = id, UserName = "unit-" + id, Email = "unit-" + id + "@example.invalid",
                FirstName = "Unit", LastName = "Synthetic", IsActive = true
            };
            Db.AddRange(new Client { Id = 11, User = User(1) },
                new Therapist { Id = 22, User = User(2), Biography = "Unit synthetic", Specialization = "Unit",
                    HourlyRate = 50.25m, VerificationStatus = TherapistVerificationStatus.Pending }, User(3),
                new Microsoft.AspNetCore.Identity.IdentityRole<int> { Id = 1, Name = "Admin", NormalizedName = "ADMIN" },
                new Microsoft.AspNetCore.Identity.IdentityUserRole<int> { UserId = 3, RoleId = 1 });
            await Db.SaveChangesAsync();
        }
        public async ValueTask DisposeAsync()
        {
            scope.Dispose(); await provider.DisposeAsync(); await Db.DisposeAsync(); http.Dispose();
        }
    }

    private sealed class FakeStripeHandler : HttpMessageHandler
    {
        public int Requests { get; private set; }
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token)
        {
            Requests++;
            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.Equal("/v1/payment_intents/pi_unit", request.RequestUri!.AbsolutePath);
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"id\":\"pi_unit\",\"object\":\"payment_intent\",\"amount\":100,\"currency\":\"usd\",\"status\":\"requires_payment_method\"}", Encoding.UTF8, "application/json")
            });
        }
    }
}
