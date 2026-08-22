using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using MindBloom.API.Controllers;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Security;
using MindBloom.IntegrationTests.StripeSandbox.Infrastructure;
using MindBloom.Shared.Observability;
using Stripe;

namespace MindBloom.IntegrationTests.StripeSandbox;

public sealed class StripeSandboxWorkflowTests
    : IClassFixture<StripeSandboxFixture>
{
    private readonly StripeSandboxFixture
        _fixture;

    public StripeSandboxWorkflowTests(
        StripeSandboxFixture fixture)
    {
        _fixture =
            fixture;
    }

    [Fact]
    public async Task
        SuccessfulPayment_UsingStripeSandbox_Succeeds()
    {
        var paymentIntent =
            await _fixture
                .CreateAndConfirmSuccessfulPaymentAsync();

        Assert.NotNull(
            paymentIntent);

        Assert.False(
            string.IsNullOrWhiteSpace(
                paymentIntent.Id));

        Assert.StartsWith(
            "pi_",
            paymentIntent.Id);

        Assert.Equal(
            "succeeded",
            paymentIntent.Status);

        Assert.Equal(
            5000,
            paymentIntent.Amount);

        Assert.Equal(
            5000,
            paymentIntent.AmountReceived);

        Assert.Equal(
            "usd",
            paymentIntent.Currency);

        Assert.False(
            paymentIntent.Livemode);
    }

    [Fact]
    public async Task
        DeclinedCard_UsingStripeSandbox_IsRejected()
    {
        var service =
            _fixture
                .CreatePaymentIntentService();

        var exception =
            await Assert.ThrowsAsync<
                StripeException>(
                async () =>
                {
                    await service.CreateAsync(
                        new PaymentIntentCreateOptions
                        {
                            Amount =
                                5000,

                            Currency =
                                "usd",

                            PaymentMethodTypes =
                                new List<string>
                                {
                                    "card"
                                },

                            /*
                             * Stripe test PaymentMethod
                             * koji simulira odbijenu karticu.
                             */
                            PaymentMethod =
                                "pm_card_visa_chargeDeclined",

                            Confirm =
                                true,

                            Metadata =
                                new Dictionary<
                                    string,
                                    string>
                                {
                                    ["testSuite"] =
                                        "MindBloom",

                                    ["testType"] =
                                        "DeclinedCard"
                                }
                        });
                });

        Assert.NotNull(
            exception.StripeError);

        Assert.Equal(
            "card_declined",
            exception.StripeError.Code);
    }

    [Fact]
    public async Task
        Refund_UsingStripeSandbox_Succeeds()
    {
        var paymentIntent =
            await _fixture
                .CreateAndConfirmSuccessfulPaymentAsync();

        Assert.Equal(
            "succeeded",
            paymentIntent.Status);

        var refundService =
            _fixture
                .CreateRefundService();

        var refund =
            await refundService
                .CreateAsync(
                    new RefundCreateOptions
                    {
                        PaymentIntent =
                            paymentIntent.Id,

                        Amount =
                            paymentIntent
                                .AmountReceived,

                        Reason =
                            RefundReasons
                                .RequestedByCustomer,

                        Metadata =
                            new Dictionary<
                                string,
                                string>
                            {
                                ["testSuite"] =
                                    "MindBloom",

                                ["testType"] =
                                    "Refund"
                            }
                    });

        Assert.NotNull(
            refund);

        Assert.StartsWith(
            "re_",
            refund.Id);

        Assert.Equal(
            "succeeded",
            refund.Status);

        Assert.Equal(
            paymentIntent.AmountReceived,
            refund.Amount);

        Assert.Equal(
            "usd",
            refund.Currency);
    }

    [Fact]
    public async Task
        Webhook_WithValidSignature_IsProcessed()
    {
        var eventId =
            $"evt_mindbloom_"
            + $"{Guid.NewGuid():N}";

        var payload =
            CreateWebhookPayload(
                eventId);

        await using var context =
            _fixture
                .CreateDbContext();

        var webhookService =
            CreateWebhookService(
                context);

        var controller =
            CreateWebhookController(
                webhookService,
                payload,
                _fixture.WebhookSecret);

        var result =
            await controller
                .Webhook(
                    CancellationToken.None);

        var okResult =
            Assert.IsType<
                OkObjectResult>(
                result);

        Assert.Equal(
            StatusCodes.Status200OK,
            okResult.StatusCode
            ?? StatusCodes.Status200OK);

        context.ChangeTracker
            .Clear();

        var storedEvent =
            await context
                .StripeWebhookEvents
                .AsNoTracking()
                .SingleAsync(
                    x =>
                        x.StripeEventId ==
                        eventId);

        Assert.Equal(
            eventId,
            storedEvent
                .StripeEventId);

        Assert.Equal(
            "customer.created",
            storedEvent.EventType);

        Assert.True(
            storedEvent.IsProcessed);

        Assert.NotNull(
            storedEvent.ProcessedAtUtc);

        Assert.Null(
            storedEvent.FailureReason);
    }

    [Fact]
    public async Task
        DuplicateWebhook_WithSameEventId_IsProcessedOnce()
    {
        var eventId =
            $"evt_duplicate_"
            + $"{Guid.NewGuid():N}";

        var payload =
            CreateWebhookPayload(
                eventId);

        /*
         * Prva delivery.
         */
        await using (
            var firstContext =
                _fixture
                    .CreateDbContext())
        {
            var service =
                CreateWebhookService(
                    firstContext);

            var controller =
                CreateWebhookController(
                    service,
                    payload,
                    _fixture.WebhookSecret);

            var result =
                await controller.Webhook(
                    CancellationToken.None);

            Assert.IsType<
                OkObjectResult>(
                    result);
        }

        /*
         * Stripe može isti event poslati ponovo.
         * Koristimo isti event ID i isti payload.
         */
        await using (
            var secondContext =
                _fixture
                    .CreateDbContext())
        {
            var service =
                CreateWebhookService(
                    secondContext);

            var controller =
                CreateWebhookController(
                    service,
                    payload,
                    _fixture.WebhookSecret);

            var result =
                await controller.Webhook(
                    CancellationToken.None);

            Assert.IsType<
                OkObjectResult>(
                    result);
        }

        await using var verificationContext =
            _fixture
                .CreateDbContext();

        var matchingEvents =
            await verificationContext
                .StripeWebhookEvents
                .AsNoTracking()
                .Where(
                    x =>
                        x.StripeEventId ==
                        eventId)
                .ToListAsync();

        /*
         * Duplicate delivery ne smije napraviti
         * drugi StripeWebhookEvent zapis.
         */
        var storedEvent =
            Assert.Single(
                matchingEvents);

        Assert.True(
            storedEvent.IsProcessed);

        Assert.NotNull(
            storedEvent.ProcessedAtUtc);

        Assert.Null(
            storedEvent.FailureReason);
    }

    private StripeWebhookService
        CreateWebhookService(
            MindBloom.Infrastructure
                .Persistence.Context
                .ApplicationDbContext context)
    {
        /*
         * Koristimo customer.created event.
         *
         * StripeWebhookService ga evidentira kao
         * uspješno primljen webhook, ali taj tip
         * nema MindBloom payment/membership business
         * side-effect.
         *
         * Zato ove dependencyje webhook test ne poziva.
         */
        var paymentService =
            DispatchProxy.Create<
                IPaymentService,
                EmptyInterfaceProxy>();

        var membershipService =
            DispatchProxy.Create<
                IMembershipService,
                EmptyInterfaceProxy>();

        var outboxWriter =
            DispatchProxy.Create<
                IOutboxWriter,
                EmptyInterfaceProxy>();

        var applicationMetrics =
            new ApplicationMetrics();

        return new StripeWebhookService(
            context,
            paymentService,
            membershipService,
            applicationMetrics,
            outboxWriter,
            NullLogger<
                StripeWebhookService>
                .Instance);
    }

    private static StripeWebhookController
        CreateWebhookController(
            StripeWebhookService
                webhookService,
            string payload,
            string webhookSecret)
    {
        var stripeSettings =
            Options.Create(
                new StripeSettings
                {
                    SecretKey =
                        "sk_test_not_used_by_webhook_test",

                    WebhookSecret =
                        webhookSecret
                });

        var controller =
            new StripeWebhookController(
                webhookService,
                stripeSettings,
                NullLogger<
                    StripeWebhookController>
                    .Instance);

        var httpContext =
            new DefaultHttpContext();

        httpContext.Request.Body =
            new MemoryStream(
                Encoding.UTF8
                    .GetBytes(
                        payload));

        httpContext.Request.Headers[
            "Stripe-Signature"] =
                CreateStripeSignature(
                    payload,
                    webhookSecret);

        controller.ControllerContext =
            new ControllerContext
            {
                HttpContext =
                    httpContext
            };

        return controller;
    }

    private static string
    CreateWebhookPayload(
        string eventId)
    {
        /*
         * Koristimo API verziju koju očekuje
         * trenutno instalirana Stripe.NET biblioteka.
         *
         * Time EventUtility.ConstructEvent može
         * validirati i deserijalizovati test event
         * na isti način kao pravi Stripe webhook.
         */
        var apiVersion =
            StripeConfiguration
                .ApiVersion;

        return $$"""
    {
      "id": "{{eventId}}",
      "object": "event",
      "api_version": "{{apiVersion}}",
      "created": {{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}},
      "livemode": false,
      "pending_webhooks": 1,
      "type": "customer.created",
      "data": {
        "object": {
          "id": "cus_mindbloom_test",
          "object": "customer"
        }
      }
    }
    """;
    }

    private static string
        CreateStripeSignature(
            string payload,
            string webhookSecret)
    {
        var timestamp =
            DateTimeOffset.UtcNow
                .ToUnixTimeSeconds();

        var signedPayload =
            $"{timestamp}.{payload}";

        var secretBytes =
            Encoding.UTF8
                .GetBytes(
                    webhookSecret);

        var payloadBytes =
            Encoding.UTF8
                .GetBytes(
                    signedPayload);

        using var hmac =
            new HMACSHA256(
                secretBytes);

        var hash =
            hmac.ComputeHash(
                payloadBytes);

        var signature =
            Convert
                .ToHexString(
                    hash)
                .ToLowerInvariant();

        return
            $"t={timestamp},v1={signature}";
    }

    private class
        EmptyInterfaceProxy
        : DispatchProxy
    {
        protected override object?
            Invoke(
                System.Reflection
                    .MethodInfo?
                    targetMethod,
                object?[]?
                    args)
        {
            if (targetMethod is null)
            {
                return null;
            }

            var returnType =
                targetMethod.ReturnType;

            if (returnType ==
                typeof(void))
            {
                return null;
            }

            if (returnType ==
                typeof(Task))
            {
                return Task.CompletedTask;
            }

            if (returnType.IsGenericType &&
                returnType
                    .GetGenericTypeDefinition() ==
                typeof(Task<>))
            {
                var resultType =
                    returnType
                        .GetGenericArguments()[0];

                var defaultValue =
                    resultType.IsValueType
                        ? Activator
                            .CreateInstance(
                                resultType)
                        : null;

                var fromResult =
                    typeof(Task)
                        .GetMethod(
                            nameof(
                                Task.FromResult))!
                        .MakeGenericMethod(
                            resultType);

                return fromResult
                    .Invoke(
                        null,
                        new[]
                        {
                            defaultValue
                        });
            }

            if (!returnType
                    .IsValueType ||
                Nullable.GetUnderlyingType(
                    returnType) is not null)
            {
                return null;
            }

            return Activator
                .CreateInstance(
                    returnType);
        }
    }
}