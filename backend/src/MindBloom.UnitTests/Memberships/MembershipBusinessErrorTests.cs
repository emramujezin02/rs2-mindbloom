using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Security;
using Moq;

namespace MindBloom.UnitTests.Memberships;

public sealed partial class MembershipServiceTests
{
    [Theory]
    [InlineData(false, PaymentStatus.Pending, "This membership payment does not belong to you.")]
    [InlineData(true, PaymentStatus.Refunded, "This membership payment has been refunded.")]
    public async Task ConfirmPaymentAsync_WhenOwnershipOrStateIsInvalid_ThrowsBusinessException(
        bool owned, PaymentStatus status, string message)
    {
        await using var context = CreateContext();
        var client = await SeedClientAsync(context);
        var therapist = await SeedTherapistAsync(context);
        var membership = await SeedMembershipPaymentAsync(context, client.Id, therapist.Id, status);
        if (!owned)
        {
            membership.ClientId = client.Id + 100;
            await context.SaveChangesAsync();
        }

        var exception = await Assert.ThrowsAsync<BusinessException>(() =>
            CreateService(context).ConfirmPaymentAsync(client.UserId,
                new ConfirmMembershipPaymentDto { PaymentIntentId = "pi_membership_test" }));

        Assert.Equal(message, exception.Message);
        Assert.False(membership.IsActive);
        Assert.Equal(status, membership.Payment!.Status);
    }

    [Theory]
    [InlineData("status", "Stripe membership payment has not succeeded. Current status: processing.")]
    [InlineData("amount", "Stripe membership amount does not match the server-calculated price.")]
    [InlineData("currency", "Stripe membership currency is invalid.")]
    [InlineData("purchaseType", "Stripe payment is not a membership purchase.")]
    [InlineData("membershipId", "Stripe payment is linked to a different membership.")]
    [InlineData("clientUserId", "Stripe payment is linked to a different user.")]
    [InlineData("clientId", "Stripe payment is linked to a different client.")]
    [InlineData("therapistId", "Stripe payment is linked to a different therapist.")]
    [InlineData("none", "")]
    public async Task ConfirmPaymentAsync_WhenStripeDataIsInvalid_ThrowsBusinessException(
        string invalidField, string message)
    {
        await using var context = CreateContext();
        var client = await SeedClientAsync(context);
        var therapist = await SeedTherapistAsync(context);
        var membership = await SeedMembershipPaymentAsync(context, client.Id, therapist.Id);
        var metadata = new Dictionary<string, string>
        {
            ["purchaseType"] = "membership", ["membershipId"] = membership.Id.ToString(),
            ["clientUserId"] = client.UserId.ToString(), ["clientId"] = client.Id.ToString(),
            ["therapistId"] = therapist.Id.ToString()
        };
        if (metadata.ContainsKey(invalidField))
        {
            metadata[invalidField] = "invalid";
        }
        var json = JsonSerializer.Serialize(new
        {
            id = "pi_membership_test", @object = "payment_intent",
            status = invalidField == "status" ? "processing" : "succeeded",
            amount = invalidField == "amount" ? 1 : 40000,
            currency = invalidField == "currency" ? "eur" : "usd", metadata
        });
        using var httpClient = new HttpClient(new StripeResponseHandler(json));
        var service = CreateService(context, verification: CreateStripeVerificationService(httpClient));

        if (invalidField == "none")
        {
            var result = await service.ConfirmPaymentAsync(client.UserId,
                new ConfirmMembershipPaymentDto { PaymentIntentId = "pi_membership_test" });
            Assert.Equal(membership.Id, result.Id);
            Assert.True(membership.IsActive);
            Assert.Equal(10, membership.RemainingSessions);
            Assert.Equal(PaymentStatus.Paid, membership.Payment!.Status);
            Assert.Equal(membership.PurchasedAtUtc!.Value.AddMonths(6), membership.ExpiresAtUtc);
            var receipt = await service.GetReceiptAsync(client.UserId, membership.Id);
            Assert.NotNull(receipt);
            return;
        }

        var exception = await Assert.ThrowsAsync<BusinessException>(() =>
            service.ConfirmPaymentAsync(client.UserId,
                    new ConfirmMembershipPaymentDto { PaymentIntentId = "pi_membership_test" }));

        Assert.Equal(message, exception.Message);
        Assert.False(membership.IsActive);
        Assert.Equal(0, membership.RemainingSessions);
        Assert.Equal(PaymentStatus.Pending, membership.Payment!.Status);
    }

    [Fact]
    public async Task ConfirmPaymentAsync_WhenStripeFails_RemainsSystemError()
    {
        await using var context = CreateContext();
        var client = await SeedClientAsync(context);
        var therapist = await SeedTherapistAsync(context);
        await SeedMembershipPaymentAsync(context, client.Id, therapist.Id);
        using var httpClient = new HttpClient(new StripeResponseHandler(
            "{\"error\":{\"type\":\"api_error\",\"message\":\"Provider unavailable\"}}",
            HttpStatusCode.InternalServerError));

        var exception = await Assert.ThrowsAsync<Exception>(() =>
            CreateService(context, verification: CreateStripeVerificationService(httpClient))
                .ConfirmPaymentAsync(client.UserId,
                    new ConfirmMembershipPaymentDto { PaymentIntentId = "pi_membership_test" }));

        Assert.Equal("Membership payment could not be verified with Stripe.", exception.Message);
        Assert.IsType<Stripe.StripeException>(exception.InnerException);
    }

    [Fact]
    public async Task GetReceiptAsync_WhenMembershipIsUnpaid_ThrowsBusinessException()
    {
        await using var context = CreateContext();
        var client = await SeedClientAsync(context);
        var therapist = await SeedTherapistAsync(context);
        var membership = await SeedMembershipPaymentAsync(context, client.Id, therapist.Id);

        var exception = await Assert.ThrowsAsync<BusinessException>(() =>
            CreateService(context).GetReceiptAsync(client.UserId, membership.Id));

        Assert.Equal("Receipt is available only for a paid membership.", exception.Message);
    }

    [Theory]
    [InlineData(MembershipUsageStatus.Reserved)]
    [InlineData(MembershipUsageStatus.Consumed)]
    [InlineData(MembershipUsageStatus.Restored)]
    [InlineData((MembershipUsageStatus)99)]
    public async Task FinalizeAppointmentUsageAsync_RespectsUsageState(MembershipUsageStatus status)
    {
        await using var context = CreateContext();
        var usage = new MembershipUsage { AppointmentId = 123, ClientMembershipId = 456, Status = status };
        context.MembershipUsages.Add(usage);
        await context.SaveChangesAsync();
        var service = CreateService(context);

        if (status == (MembershipUsageStatus)99)
        {
            var exception = await Assert.ThrowsAsync<BusinessException>(() =>
                service.FinalizeAppointmentUsageAsync(123, "Completed"));
            Assert.Equal("Membership usage is not in a valid reserved state.", exception.Message);
            Assert.Equal(status, usage.Status);
        }
        else
        {
            await service.FinalizeAppointmentUsageAsync(123, "Completed");
            Assert.Equal(status == MembershipUsageStatus.Reserved ? MembershipUsageStatus.Consumed : status,
                usage.Status);
        }
    }

    private static async Task<ClientMembership> SeedMembershipPaymentAsync(
        ApplicationDbContext context, int clientId, int therapistId, PaymentStatus status = PaymentStatus.Pending)
    {
        var membership = new ClientMembership
        {
            ClientId = clientId, TherapistId = therapistId, PlanType = MembershipPlanType.TenSessions,
            TotalSessions = 10, RemainingSessions = 0, Price = 400m, DurationMonths = 6, IsActive = false,
            Payment = new MembershipPayment
            {
                Amount = 400m, Currency = "usd", Status = status, StripePaymentIntentId = "pi_membership_test"
            }
        };
        context.ClientMemberships.Add(membership);
        await context.SaveChangesAsync();
        return membership;
    }

    private static StripeVerificationService CreateStripeVerificationService(HttpClient httpClient)
    {
        var factory = new Mock<IHttpClientFactory>();
        factory.Setup(x => x.CreateClient("Stripe")).Returns(httpClient);
        return new StripeVerificationService(new StripeClientProvider(factory.Object,
            Options.Create(new StripeSettings { SecretKey = "sk_test_unit_tests_only" }),
            Options.Create(new ExternalServiceResilienceOptions { StripeMaxNetworkRetries = 0 }),
            NullLogger<StripeClientProvider>.Instance));
    }

    private sealed class StripeResponseHandler(string json, HttpStatusCode status = HttpStatusCode.OK)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(new HttpResponseMessage(status)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json")
            });
    }
}
