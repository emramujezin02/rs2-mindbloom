using System.Net;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Security;
using MindBloom.Infrastructure.Services;
using Moq;

namespace MindBloom.UnitTests.Memberships;

public sealed partial class MembershipServiceTests
{
    [Fact]
    public async Task CreatePaymentIntentAsync_ResolvedFromDI_UsesRegisteredStripeClient()
    {
        await using var context = CreateContext();
        var client = await SeedClientAsync(context);
        var therapist = await SeedTherapistAsync(context);
        context.MembershipPlans.Add(CreatePlan(
            MembershipPlanType.TenSessions, "Ten sessions", 400m, 10, true));
        await context.SaveChangesAsync();

        using var handler = new MembershipStripeCreationHandler();
        using var httpClient = new HttpClient(handler);
        var httpClientFactory = new Mock<IHttpClientFactory>();
        httpClientFactory.Setup(x => x.CreateClient("Stripe")).Returns(httpClient);
        var stripeProvider = new StripeClientProvider(httpClientFactory.Object,
            Options.Create(new StripeSettings { SecretKey = "sk_test_unit_tests_only" }),
            Options.Create(new ExternalServiceResilienceOptions { StripeMaxNetworkRetries = 0 }),
            NullLogger<StripeClientProvider>.Instance);

        var services = new ServiceCollection();
        services.AddSingleton(context);
        services.AddSingleton(stripeProvider);
        services.AddScoped<StripeVerificationService>();
        services.AddSingleton(Mock.Of<IIntegrationEventPublisher>());
        services.AddSingleton(Mock.Of<IOutboxWriter>());
        services.AddScoped<IMembershipService, MembershipService>();
        await using var serviceProvider = services.BuildServiceProvider();
        await using var scope = serviceProvider.CreateAsyncScope();
        var service = scope.ServiceProvider.GetRequiredService<IMembershipService>();

        var result = await service.CreatePaymentIntentAsync(client.UserId,
            new CreateMembershipPaymentIntentDto
            {
                TherapistId = therapist.Id, PlanType = MembershipPlanType.TenSessions
            });

        Assert.Equal("pi_membership_creation_test", result.PaymentIntentId);
        Assert.Equal("pi_membership_creation_test_secret", result.ClientSecret);
        Assert.Equal(400m, result.Amount);
        Assert.Equal("usd", result.Currency);
        Assert.Equal(1, handler.RequestCount);
        Assert.Equal($"mindbloom-membership-{result.MembershipId}", handler.IdempotencyKey);
        Assert.Contains("amount=40000", handler.RequestBody);
        Assert.Contains("currency=usd", handler.RequestBody);
        Assert.Contains($"metadata[membershipId]={result.MembershipId}", handler.RequestBody);
        Assert.Contains("metadata[purchaseType]=membership", handler.RequestBody);

        var membership = await context.ClientMemberships.SingleAsync();
        var payment = await context.MembershipPayments.SingleAsync();
        Assert.Equal(result.MembershipId, membership.Id);
        Assert.False(membership.IsActive);
        Assert.Equal(0, membership.RemainingSessions);
        Assert.Equal(10, membership.TotalSessions);
        Assert.Equal(PaymentStatus.Pending, payment.Status);
        Assert.Equal(membership.Id, payment.ClientMembershipId);
        Assert.Equal(result.PaymentIntentId, payment.StripePaymentIntentId);
        Assert.Equal(400m, payment.Amount);
        Assert.Equal("usd", payment.Currency);
    }

    private sealed class MembershipStripeCreationHandler : HttpMessageHandler
    {
        public int RequestCount { get; private set; }
        public string RequestBody { get; private set; } = string.Empty;
        public string IdempotencyKey { get; private set; } = string.Empty;

        protected override async Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Assert.Equal(HttpMethod.Post, request.Method);
            Assert.Equal("/v1/payment_intents", request.RequestUri!.AbsolutePath);
            RequestCount++;
            RequestBody = Uri.UnescapeDataString(
                await request.Content!.ReadAsStringAsync(cancellationToken));
            IdempotencyKey = Assert.Single(request.Headers.GetValues("Idempotency-Key"));
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("""
                    {"id":"pi_membership_creation_test","object":"payment_intent",
                     "client_secret":"pi_membership_creation_test_secret","amount":40000,
                     "currency":"usd","status":"requires_payment_method","livemode":false}
                    """, Encoding.UTF8, "application/json")
            };
        }
    }
}
