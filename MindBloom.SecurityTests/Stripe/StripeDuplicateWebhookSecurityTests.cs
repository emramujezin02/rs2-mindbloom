using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;
using Xunit;

namespace MindBloom.SecurityTests.Stripe;

public sealed class StripeDuplicateWebhookSecurityTests
{
    [Fact]
    public async Task
        ProcessAsync_WhenEventWasAlreadyProcessed_DoesNotProcessItAgain()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"stripe-duplicate-{Guid.NewGuid():N}")
                .Options;

        await using var context =
            new ApplicationDbContext(
                options);

        const string stripeEventId =
            "evt_security_duplicate_001";

        /*
         * Simuliramo Stripe event koji je već
         * uspješno obrađen u prethodnom requestu.
         */
        context.StripeWebhookEvents.Add(
            new StripeWebhookEvent
            {
                StripeEventId =
                    stripeEventId,

                EventType =
                    "payment_intent.succeeded",

                StripePaymentIntentId =
                    "pi_security_duplicate_001",

                ReceivedAtUtc =
                    DateTime.UtcNow
                        .AddMinutes(-1),

                IsProcessed =
                    true,

                ProcessedAtUtc =
                    DateTime.UtcNow
                        .AddMinutes(-1),

                FailureReason =
                    null,

                CreatedAtUtc =
                    DateTime.UtcNow
                        .AddMinutes(-1)
            });

        await context.SaveChangesAsync();

        var paymentService =
            new Mock<IPaymentService>();

        var membershipService =
            new Mock<IMembershipService>();

        var logger =
            new Mock<
                ILogger<StripeWebhookService>>();

        var service =
            new StripeWebhookService(
                context,
                paymentService.Object,
                membershipService.Object,
                logger.Object);

        var duplicateEvent =
            new Event
            {
                Id =
                    stripeEventId,

                Type =
                    "payment_intent.succeeded"
            };

        /*
         * Pošto je event već obrađen,
         * metoda mora završiti prije bilo
         * kakve payment/membership obrade.
         */
        await service.ProcessAsync(
            duplicateEvent);

        paymentService.VerifyNoOtherCalls();

        membershipService.VerifyNoOtherCalls();

        var storedEvents =
            await context.StripeWebhookEvents
                .Where(x =>
                    x.StripeEventId ==
                        stripeEventId)
                .ToListAsync();

        /*
         * Ne smije nastati drugi audit/event zapis.
         */
        Assert.Single(
            storedEvents);

        var storedEvent =
            storedEvents.Single();

        Assert.True(
            storedEvent.IsProcessed);

        Assert.NotNull(
            storedEvent.ProcessedAtUtc);
    }

    [Fact]
    public async Task
        ProcessAsync_WhenProcessedEventIsDeliveredMultipleTimes_StillKeepsSingleEventRecord()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"stripe-repeat-{Guid.NewGuid():N}")
                .Options;

        await using var context =
            new ApplicationDbContext(
                options);

        const string stripeEventId =
            "evt_security_duplicate_002";

        context.StripeWebhookEvents.Add(
            new StripeWebhookEvent
            {
                StripeEventId =
                    stripeEventId,

                EventType =
                    "payment_intent.succeeded",

                StripePaymentIntentId =
                    "pi_security_duplicate_002",

                ReceivedAtUtc =
                    DateTime.UtcNow,

                IsProcessed =
                    true,

                ProcessedAtUtc =
                    DateTime.UtcNow,

                FailureReason =
                    null,

                CreatedAtUtc =
                    DateTime.UtcNow
            });

        await context.SaveChangesAsync();

        var paymentService =
            new Mock<IPaymentService>();

        var membershipService =
            new Mock<IMembershipService>();

        var logger =
            new Mock<
                ILogger<StripeWebhookService>>();

        var service =
            new StripeWebhookService(
                context,
                paymentService.Object,
                membershipService.Object,
                logger.Object);

        var duplicateEvent =
            new Event
            {
                Id =
                    stripeEventId,

                Type =
                    "payment_intent.succeeded"
            };

        /*
         * Simuliramo da Stripe isti event
         * pošalje još nekoliko puta.
         */
        await service.ProcessAsync(
            duplicateEvent);

        await service.ProcessAsync(
            duplicateEvent);

        await service.ProcessAsync(
            duplicateEvent);

        var numberOfRecords =
            await context.StripeWebhookEvents
                .CountAsync(x =>
                    x.StripeEventId ==
                        stripeEventId);

        Assert.Equal(
            1,
            numberOfRecords);

        paymentService.VerifyNoOtherCalls();

        membershipService.VerifyNoOtherCalls();
    }
}