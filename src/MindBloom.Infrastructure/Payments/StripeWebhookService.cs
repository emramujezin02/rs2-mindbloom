using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;
using MindBloom.Shared.Observability;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Messaging.Contracts.Payments;
using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Infrastructure.Payments;

public sealed class StripeWebhookService
{
    private static readonly EventId
    DuplicateWebhookIgnoredEvent =
        new(
            3200,
            "StripeDuplicateWebhookIgnored");

    private static readonly EventId
        WebhookTypeIgnoredEvent =
            new(
                3201,
                "StripeWebhookTypeIgnored");

    private static readonly EventId
        ConcurrentDuplicateWebhookIgnoredEvent =
            new(
                3202,
                "StripeConcurrentDuplicateWebhookIgnored");

    private static readonly EventId
        RefundPaymentNotFoundEvent =
            new(
                3203,
                "StripeRefundPaymentNotFound");

    private static readonly EventId
        UnsupportedRefundStatusEvent =
            new(
                3204,
                "StripeUnsupportedRefundStatus");

    private static readonly EventId
        RefundedChargePaymentNotFoundEvent =
            new(
                3205,
                "StripeRefundedChargePaymentNotFound");

    private static readonly EventId
        WebhookProcessingFailedEvent =
            new(
                3206,
                "StripeWebhookProcessingFailed");

    private const string PaymentCurrency =
        "usd";

    private readonly ApplicationDbContext
        _context;

    private readonly IPaymentService
        _paymentService;

    private readonly IMembershipService
        _membershipService;

    private readonly ApplicationMetrics
    _applicationMetrics;

    private readonly IOutboxWriter
    _outboxWriter;

    private readonly ILogger<StripeWebhookService>
        _logger;

    public StripeWebhookService(
        ApplicationDbContext context,
        IPaymentService paymentService,
        IMembershipService membershipService,
        ApplicationMetrics applicationMetrics,
        IOutboxWriter outboxWriter,
        ILogger<StripeWebhookService> logger)
    {
        _context =
            context;

        _paymentService =
            paymentService;

        _membershipService =
            membershipService;

        _applicationMetrics =
            applicationMetrics;

        _outboxWriter =
            outboxWriter;

        _logger =
            logger;
    }

    public async Task ProcessAsync(
      Event stripeEvent,
      CancellationToken cancellationToken =
          default)
    {
        ArgumentNullException.ThrowIfNull(
            stripeEvent);

        if (string.IsNullOrWhiteSpace(
                stripeEvent.Id))
        {
            throw new InvalidOperationException(
                "Stripe event identifier is missing.");
        }

        var paymentIntent =
            stripeEvent.Data?.Object
                as PaymentIntent;

        var strategy =
            _context.Database
                .CreateExecutionStrategy();

        try
        {
            await strategy.ExecuteAsync(
                async () =>
                {
                    _context.ChangeTracker.Clear();

                    var existingEvent =
                        await _context
                            .StripeWebhookEvents
                            .FirstOrDefaultAsync(
                                x =>
                                    x.StripeEventId ==
                                    stripeEvent.Id,
                                cancellationToken);

                    if (existingEvent?.IsProcessed ==
                        true)
                    {
                        _logger.LogInformation(
                            DuplicateWebhookIgnoredEvent,
                            "Duplicate Stripe webhook event ignored. "
                            + "Module: {Module}, "
                            + "StripeEventId: {StripeEventId}, "
                            + "StripeEventType: {StripeEventType}.",
                            "Payments",
                            stripeEvent.Id,
                            stripeEvent.Type);

                        return;
                    }

                    await using var transaction =
                        await _context.Database
                            .BeginTransactionAsync(
                                cancellationToken);

                    try
                    {
                        StripeWebhookEvent webhookEvent;

                        if (existingEvent == null)
                        {
                            webhookEvent =
                                new StripeWebhookEvent
                                {
                                    StripeEventId =
                                        stripeEvent.Id,

                                    EventType =
                                        stripeEvent.Type
                                        ?? string.Empty,

                                    StripePaymentIntentId =
                                        paymentIntent?.Id,

                                    ReceivedAtUtc =
                                        DateTime.UtcNow,

                                    IsProcessed =
                                        false
                                };

                            _context
                                .StripeWebhookEvents
                                .Add(webhookEvent);

                            await _context
                                .SaveChangesAsync(
                                    cancellationToken);
                        }
                        else
                        {
                            webhookEvent =
                                existingEvent;

                            webhookEvent.EventType =
                                stripeEvent.Type
                                ?? webhookEvent.EventType;

                            webhookEvent
                                .StripePaymentIntentId ??=
                                paymentIntent?.Id;
                        }

                        switch (stripeEvent.Type)
                        {
                            case "payment_intent.succeeded":
                                await HandlePaymentIntentSucceededAsync(
                                    paymentIntent,
                                    cancellationToken);

                                _applicationMetrics
                                    .RecordPaymentSuccess();

                                break;

                            case "payment_intent.payment_failed":
                            case "payment_intent.canceled":
                                await HandlePaymentIntentFailedAsync(
                                    paymentIntent,
                                    cancellationToken);

                                _applicationMetrics
                                    .RecordPaymentFailure();

                                break;

                            case "refund.updated":
                            case "refund.failed":
                                await HandleRefundEventAsync(
                                    stripeEvent,
                                    cancellationToken);

                                break;

                            case "charge.refunded":
                                await HandleChargeRefundedAsync(
                                    stripeEvent,
                                    cancellationToken);

                                break;

                            default:
                                _logger.LogInformation(
                                    WebhookTypeIgnoredEvent,
                                    "Stripe webhook event type ignored. "
                                    + "Module: {Module}, "
                                    + "StripeEventId: {StripeEventId}, "
                                    + "StripeEventType: {StripeEventType}.",
                                    "Payments",
                                    stripeEvent.Id,
                                    stripeEvent.Type);

                                break;
                        }

                        webhookEvent.IsProcessed =
                            true;

                        webhookEvent.ProcessedAtUtc =
                            DateTime.UtcNow;

                        webhookEvent.FailureReason =
                            null;

                        await _context
                            .SaveChangesAsync(
                                cancellationToken);

                        await transaction
                            .CommitAsync(
                                cancellationToken);
                    }
                    catch (DbUpdateException)
                    {
                        await transaction
                            .RollbackAsync(
                                cancellationToken);

                        _context.ChangeTracker.Clear();

                        var duplicate =
                            await _context
                                .StripeWebhookEvents
                                .AsNoTracking()
                                .FirstOrDefaultAsync(
                                    x =>
                                        x.StripeEventId ==
                                        stripeEvent.Id,
                                    cancellationToken);

                        if (duplicate != null)
                        {
                            _logger.LogInformation(
                                ConcurrentDuplicateWebhookIgnoredEvent,
                                "Concurrent duplicate Stripe webhook event ignored. "
                                + "Module: {Module}, "
                                + "StripeEventId: {StripeEventId}, "
                                + "StripeEventType: {StripeEventType}.",
                                "Payments",
                                stripeEvent.Id,
                                stripeEvent.Type);

                            return;
                        }

                        throw;
                    }
                    catch
                    {
                        await transaction
                            .RollbackAsync(
                                cancellationToken);

                        throw;
                    }
                });
        }
        catch (OperationCanceledException)
            when (cancellationToken
                .IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            await RecordFailureAsync(
                stripeEvent,
                paymentIntent?.Id,
                exception,
                cancellationToken);

            throw;
        }
    }

    private async Task
        HandlePaymentIntentSucceededAsync(
            PaymentIntent? paymentIntent,
            CancellationToken cancellationToken)
    {
        if (paymentIntent == null ||
            string.IsNullOrWhiteSpace(
                paymentIntent.Id))
        {
            throw new InvalidOperationException(
                "Stripe payment intent payload is missing.");
        }

        var metadata =
            paymentIntent.Metadata;

        if (metadata == null)
        {
            throw new InvalidOperationException(
                "Stripe payment intent metadata is missing.");
        }

        var clientUserId =
            GetRequiredIntMetadata(
                metadata,
                "clientUserId");

        if (metadata.TryGetValue(
                "purchaseType",
                out var purchaseType) &&
            string.Equals(
                purchaseType,
                "membership",
                StringComparison.OrdinalIgnoreCase))
        {
            await _membershipService
                .ConfirmPaymentAsync(
                    clientUserId,
                    new ConfirmMembershipPaymentDto
                    {
                        PaymentIntentId =
                            paymentIntent.Id
                    });

            return;
        }

        if (metadata.ContainsKey(
                "appointmentId"))
        {
            await _paymentService
                .ConfirmPaymentAsync(
                    clientUserId,
                    new ConfirmPaymentDto
                    {
                        PaymentIntentId =
                            paymentIntent.Id
                    });

            return;
        }

        throw new InvalidOperationException(
            "Stripe PaymentIntent is not linked to a supported MindBloom resource.");
    }

    private async Task
        HandlePaymentIntentFailedAsync(
            PaymentIntent? paymentIntent,
            CancellationToken cancellationToken)
    {
        if (paymentIntent == null ||
            string.IsNullOrWhiteSpace(
                paymentIntent.Id))
        {
            throw new InvalidOperationException(
                "Stripe payment intent payload is missing.");
        }

        var metadata =
            paymentIntent.Metadata;

        if (metadata == null)
        {
            throw new InvalidOperationException(
                "Stripe payment intent metadata is missing.");
        }

        if (metadata.TryGetValue(
                "purchaseType",
                out var purchaseType) &&
            string.Equals(
                purchaseType,
                "membership",
                StringComparison.OrdinalIgnoreCase))
        {
            await MarkMembershipPaymentFailedAsync(
                paymentIntent,
                cancellationToken);

            return;
        }

        if (metadata.ContainsKey(
                "appointmentId"))
        {
            await MarkAppointmentPaymentFailedAsync(
                paymentIntent,
                cancellationToken);

            return;
        }

        throw new InvalidOperationException(
            "Stripe PaymentIntent is not linked to a supported MindBloom resource.");
    }

    private async Task
        MarkAppointmentPaymentFailedAsync(
            PaymentIntent paymentIntent,
            CancellationToken cancellationToken)
    {
        var payment =
            await _context.Payments
                .Include(x =>
                    x.Appointment)
                .ThenInclude(x =>
                    x.Client)
                .FirstOrDefaultAsync(
                    x =>
                        x.StripePaymentIntentId ==
                        paymentIntent.Id,
                    cancellationToken);

        if (payment == null)
        {
            throw new InvalidOperationException(
                "Appointment payment referenced by Stripe was not found.");
        }

        ValidateAppointmentPaymentIntent(
            paymentIntent,
            payment);

        if (payment.Status is
            PaymentStatus.Paid or
            PaymentStatus.Refunded or
            PaymentStatus.RefundPending)
        {
            return;
        }

        payment.Status =
            PaymentStatus.Failed;

        payment.Appointment.IsPaid =
            false;

        await _context
            .SaveChangesAsync(
                cancellationToken);
    }

    private async Task
        MarkMembershipPaymentFailedAsync(
            PaymentIntent paymentIntent,
            CancellationToken cancellationToken)
    {
        var membershipPayment =
            await _context
                .MembershipPayments
                .Include(x =>
                    x.ClientMembership)
                .ThenInclude(x =>
                    x.Client)
                .FirstOrDefaultAsync(
                    x =>
                        x.StripePaymentIntentId ==
                        paymentIntent.Id,
                    cancellationToken);

        if (membershipPayment == null)
        {
            throw new InvalidOperationException(
                "Membership payment referenced by Stripe was not found.");
        }

        ValidateMembershipPaymentIntent(
            paymentIntent,
            membershipPayment);

        if (membershipPayment.Status is
            PaymentStatus.Paid or
            PaymentStatus.Refunded or
            PaymentStatus.RefundPending)
        {
            return;
        }

        membershipPayment.Status =
            PaymentStatus.Failed;

        var membership =
            membershipPayment
                .ClientMembership;

        membership.IsActive =
            false;

        membership.RemainingSessions =
            0;

        membership.PurchasedAtUtc =
            null;

        membership.ExpiresAtUtc =
            null;

        await _context
            .SaveChangesAsync(
                cancellationToken);
    }

    private async Task HandleRefundEventAsync(
    Event stripeEvent,
    CancellationToken cancellationToken)
    {
        if (stripeEvent.Data.Object is not Refund refund ||
            string.IsNullOrWhiteSpace(
                refund.Id))
        {
            throw new InvalidOperationException(
                "Stripe refund payload is missing.");
        }

        var paymentIntentId =
            ResolvePaymentIntentId(
                refund);

        if (string.IsNullOrWhiteSpace(
                paymentIntentId))
        {
            throw new InvalidOperationException(
                "Stripe refund does not reference a payment intent.");
        }

        var payment =
            await _context.Payments
                .Include(x =>
                    x.Appointment)
                .FirstOrDefaultAsync(
                    x =>
                        x.StripePaymentIntentId ==
                        paymentIntentId,
                    cancellationToken);

        if (payment == null)
        {
            _logger.LogInformation(
                RefundPaymentNotFoundEvent,
                "Stripe refund event does not reference a MindBloom appointment payment. Module: {Module}, StripeEventId: {StripeEventId}, RefundId: {RefundId}.",
                "Payments",
                stripeEvent.Id,
                refund.Id);

            return;
        }

        ValidateRefundAmount(
            refund,
            payment);

        if (!string.IsNullOrWhiteSpace(
                payment.StripeRefundId) &&
            !string.Equals(
                payment.StripeRefundId,
                refund.Id,
                StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                "Stripe refund identifier does not match the stored payment refund.");
        }

        payment.StripeRefundId =
            refund.Id;

        var now =
            DateTime.UtcNow;

        switch (refund.Status)
        {
            case "succeeded":
                payment.Status =
                    PaymentStatus.Refunded;

                payment.RefundedAtUtc ??=
                    now;

                payment.RefundFailureReason =
                    null;

                payment.Appointment.IsPaid =
                    false;

                break;

            case "pending":
            case "requires_action":
                payment.Status =
                    PaymentStatus.RefundPending;

                payment.RefundFailureReason =
                    null;

                break;

            case "failed":
            case "canceled":
                payment.Status =
                    PaymentStatus.RefundFailed;

                payment.RefundFailureReason =
                    "Stripe refund failed.";

                break;

            default:

                _logger.LogWarning(
                    UnsupportedRefundStatusEvent,
                    "Stripe refund has an unsupported status. Module: {Module}, RefundId: {RefundId}, RefundStatus: {RefundStatus}.",
                    "Payments",
                    refund.Id,
                    refund.Status);

                return;
        }

        await EnqueueRefundedWebhookEventAsync(
    payment,
    cancellationToken);

        await _context
            .SaveChangesAsync(
                cancellationToken);
    }

    private async Task
    EnqueueRefundedWebhookEventAsync(
        Payment payment,
        CancellationToken cancellationToken)
    {
        if (payment.Status !=
            PaymentStatus.Refunded)
        {
            return;
        }



        var clientUserId =
            await _context.Appointments
                .Where(x =>
                    x.Id ==
                    payment.AppointmentId)
                .Select(x =>
                    x.Client.UserId)
                .FirstOrDefaultAsync(
                    cancellationToken);

        if (clientUserId <= 0)
        {
            throw new InvalidOperationException(
                "Refunded payment client could not be resolved.");
        }

        await _outboxWriter.EnqueueAsync(
     new PaymentRefundedEvent
     {
         PaymentId =
             payment.Id,

         PaymentType =
             "Appointment",

         AppointmentId =
             payment.AppointmentId,

         MembershipId =
             null,

         ClientUserId =
             clientUserId,

         Amount =
             payment.Amount,

         Currency =
             PaymentCurrency,

         Reason =
             payment.RefundReason,

         RefundedAtUtc =
             payment.RefundedAtUtc
             ?? DateTime.UtcNow
     },
     IntegrationEventRoutingKeys
         .PaymentRefunded,
     cancellationToken,
     idempotencyKey:
         $"payment-refunded:{payment.Id}");
    }

    private async Task HandleChargeRefundedAsync(
        Event stripeEvent,
        CancellationToken cancellationToken)
    {
        if (stripeEvent.Data.Object is not Charge charge ||
            string.IsNullOrWhiteSpace(
                charge.Id))
        {
            throw new InvalidOperationException(
                "Stripe charge payload is missing.");
        }

        var paymentIntentId =
            ResolvePaymentIntentId(
                charge);

        if (string.IsNullOrWhiteSpace(
                paymentIntentId))
        {
            throw new InvalidOperationException(
                "Refunded Stripe charge does not reference a payment intent.");
        }

        var payment =
            await _context.Payments
                .Include(x =>
                    x.Appointment)
                .FirstOrDefaultAsync(
                    x =>
                        x.StripePaymentIntentId ==
                        paymentIntentId,
                    cancellationToken);

        if (payment == null)
        {
            _logger.LogInformation(
                RefundedChargePaymentNotFoundEvent,
                "Stripe refunded charge does not reference a MindBloom appointment payment. Module: {Module}, StripeEventId: {StripeEventId}, ChargeId: {ChargeId}.",
                "Payments",
                stripeEvent.Id,
                charge.Id);

            return;
        }

        payment.Status =
      PaymentStatus.Refunded;

        payment.RefundedAtUtc ??=
            DateTime.UtcNow;

        payment.RefundFailureReason =
            null;

        payment.Appointment.IsPaid =
            false;

        await EnqueueRefundedWebhookEventAsync(
            payment,
            cancellationToken);

        await _context
            .SaveChangesAsync(
                cancellationToken);
    }

    private static string?
    ResolvePaymentIntentId(
        Refund refund)
    {

        if (refund.PaymentIntent != null &&
            !string.IsNullOrWhiteSpace(
                refund.PaymentIntent.Id))
        {
            return refund.PaymentIntent.Id;
        }

        return refund.PaymentIntentId;
    }

    private static string?
        ResolvePaymentIntentId(
            Charge charge)
    {
        if (charge.PaymentIntent != null &&
            !string.IsNullOrWhiteSpace(
                charge.PaymentIntent.Id))
        {
            return charge.PaymentIntent.Id;
        }

        return charge.PaymentIntentId;
    }

    private static void ValidateRefundAmount(
    Refund refund,
    Payment payment)
    {
        if (refund.Amount <= 0)
        {
            throw new InvalidOperationException(
                "Stripe refund amount is invalid.");
        }

        var expectedAmount =
            ConvertToMinorUnits(
                payment.Amount);

        if (refund.Amount >
            expectedAmount)
        {
            throw new InvalidOperationException(
                "Stripe refund amount exceeds the stored payment amount.");
        }

        if (!string.IsNullOrWhiteSpace(
                refund.Currency) &&
            !string.Equals(
                refund.Currency,
                PaymentCurrency,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Stripe refund currency does not match the configured currency.");
        }
    }

    private static void
        ValidateAppointmentPaymentIntent(
            PaymentIntent paymentIntent,
            Payment payment)
    {
        var metadata =
            paymentIntent.Metadata
            ?? throw new InvalidOperationException(
                "Stripe appointment payment metadata is missing.");

        var appointmentId =
            GetRequiredIntMetadata(
                metadata,
                "appointmentId");

        var clientUserId =
            GetRequiredIntMetadata(
                metadata,
                "clientUserId");

        var clientId =
            GetRequiredIntMetadata(
                metadata,
                "clientId");

        if (appointmentId !=
            payment.AppointmentId)
        {
            throw new InvalidOperationException(
                "Stripe appointment reference does not match the stored payment.");
        }

        if (clientId !=
            payment.Appointment.ClientId)
        {
            throw new InvalidOperationException(
                "Stripe client reference does not match the stored appointment.");
        }

        if (clientUserId !=
            payment.Appointment
                .Client.UserId)
        {
            throw new InvalidOperationException(
                "Stripe user reference does not match the stored appointment.");
        }

        if (paymentIntent.Amount !=
            ConvertToMinorUnits(
                payment.Amount))
        {
            throw new InvalidOperationException(
                "Stripe appointment amount does not match the stored payment amount.");
        }

        if (!string.Equals(
                paymentIntent.Currency,
                PaymentCurrency,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Stripe appointment currency does not match the configured currency.");
        }
    }

    private static void
        ValidateMembershipPaymentIntent(
            PaymentIntent paymentIntent,
            MembershipPayment payment)
    {
        var metadata =
            paymentIntent.Metadata
            ?? throw new InvalidOperationException(
                "Stripe membership payment metadata is missing.");

        if (!metadata.TryGetValue(
                "purchaseType",
                out var purchaseType) ||
            !string.Equals(
                purchaseType,
                "membership",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Stripe membership purchase type is invalid.");
        }

        var membershipId =
            GetRequiredIntMetadata(
                metadata,
                "membershipId");

        var clientUserId =
            GetRequiredIntMetadata(
                metadata,
                "clientUserId");

        var clientId =
            GetRequiredIntMetadata(
                metadata,
                "clientId");

        var therapistId =
            GetRequiredIntMetadata(
                metadata,
                "therapistId");

        var membership =
            payment.ClientMembership;

        if (membershipId !=
            membership.Id)
        {
            throw new InvalidOperationException(
                "Stripe membership reference does not match the stored membership.");
        }

        if (clientId !=
            membership.ClientId)
        {
            throw new InvalidOperationException(
                "Stripe client reference does not match the stored membership.");
        }

        if (clientUserId !=
            membership.Client.UserId)
        {
            throw new InvalidOperationException(
                "Stripe user reference does not match the stored membership.");
        }

        if (therapistId !=
            membership.TherapistId)
        {
            throw new InvalidOperationException(
                "Stripe therapist reference does not match the stored membership.");
        }

        if (paymentIntent.Amount !=
            ConvertToMinorUnits(
                payment.Amount))
        {
            throw new InvalidOperationException(
                "Stripe membership amount does not match the stored payment amount.");
        }

        if (!string.Equals(
                paymentIntent.Currency,
                payment.Currency,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Stripe membership currency does not match the stored payment currency.");
        }
    }

    private async Task RecordFailureAsync(
        Event stripeEvent,
        string? paymentIntentId,
        Exception exception,
        CancellationToken cancellationToken)
    {
        _context.ChangeTracker.Clear();

        var webhookEvent =
            await _context
                .StripeWebhookEvents
                .FirstOrDefaultAsync(
                    x =>
                        x.StripeEventId ==
                        stripeEvent.Id,
                    cancellationToken);

        if (webhookEvent == null)
        {
            webhookEvent =
                new StripeWebhookEvent
                {
                    StripeEventId =
                        stripeEvent.Id,

                    EventType =
                        stripeEvent.Type
                        ?? string.Empty,

                    StripePaymentIntentId =
                        paymentIntentId,

                    ReceivedAtUtc =
                        DateTime.UtcNow,

                    IsProcessed =
                        false
                };

            _context
                .StripeWebhookEvents
                .Add(webhookEvent);
        }

        webhookEvent.IsProcessed =
            false;

        webhookEvent.ProcessedAtUtc =
            null;

        webhookEvent.FailureReason =
            CreateSafeFailureReason(
                exception);

        try
        {
            await _context
                .SaveChangesAsync(
                    cancellationToken);
        }
        catch (DbUpdateException)
        {

        }

        _logger.LogWarning(
            WebhookProcessingFailedEvent,
            "Stripe webhook processing failed and was recorded for retry. Module: {Module}, StripeEventId: {StripeEventId}, StripeEventType: {StripeEventType}, FailureType: {FailureType}.",
            "Payments",
            stripeEvent.Id,
            stripeEvent.Type,
            exception.GetType().Name);
    }

    private static string
        CreateSafeFailureReason(
            Exception exception)
    {
        /*
         * Store only exception TYPE.
         *
         * Stripe errors may contain payment
         * details in their messages, therefore
         * the raw exception message is not
         * persisted in the audit table.
         */
        var value =
            $"Processing failed: "
            + $"{exception.GetType().Name}";

        return value.Length <=
               1000
            ? value
            : value[..1000];
    }

    private static int
        GetRequiredIntMetadata(
            IReadOnlyDictionary<string, string>
                metadata,
            string key)
    {
        if (!metadata.TryGetValue(
                key,
                out var value) ||
            !int.TryParse(
                value,
                out var result) ||
            result <= 0)
        {
            throw new InvalidOperationException(
                $"Required Stripe metadata '{key}' is missing or invalid.");
        }

        return result;
    }

    private static long
        ConvertToMinorUnits(
            decimal amount)
    {
        return decimal.ToInt64(
            decimal.Round(
                amount * 100,
                0,
                MidpointRounding
                    .AwayFromZero));
    }
}