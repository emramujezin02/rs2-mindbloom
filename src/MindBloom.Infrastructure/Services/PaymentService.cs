using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Messaging.Contracts.Payments;

namespace MindBloom.Infrastructure.Services;

public class PaymentService : IPaymentService
{
    private const string PaymentCurrency = "usd";

    private readonly ApplicationDbContext _context;
    private readonly StripeClientProvider
    _stripeClientProvider;

    private readonly IOutboxWriter
    _outboxWriter;

    private readonly StripeVerificationService _stripeVerificationService;

    private readonly IBusinessNotificationService _businessNotificationService;
    private readonly IIntegrationEventPublisher
    _integrationEventPublisher;
    public PaymentService(
        ApplicationDbContext context,
        StripeVerificationService
            stripeVerificationService,
        IBusinessNotificationService
            businessNotificationService,
        IIntegrationEventPublisher
            integrationEventPublisher,
        IOutboxWriter outboxWriter)
    {
        _context =
            context;

        _stripeVerificationService =
            stripeVerificationService;

        _businessNotificationService =
            businessNotificationService;

        _integrationEventPublisher =
            integrationEventPublisher;

        _outboxWriter =
            outboxWriter;
    }

    public async Task<PaymentIntentResponseDto>
        CreatePaymentIntentAsync(
            int clientUserId,
            CreatePaymentIntentDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .Include(x => x.Therapist)
    .ThenInclude(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id == request.AppointmentId);

        if (appointment == null)
        {
            throw new NotFoundException(
                "Appointment not found.");
        }

        if (appointment.ClientId != client.Id)
        {
            BusinessRuleGuard.AgainstNotOwned(
    appointment.ClientId == client.Id,
    "This appointment does not belong to you.");
        }

        if (appointment.Status !=
            AppointmentStatus.Accepted)
        {
            BusinessRuleGuard.Against(
    appointment.Status !=
    AppointmentStatus.Accepted,
    "Only accepted appointments can be paid.");
        }

        if (appointment.IsPaid)
        {
            BusinessRuleGuard.Against(
    appointment.IsPaid,
    "This appointment is already paid.");
        }

        var existingPayment =
            await _context.Payments
                .FirstOrDefaultAsync(x =>
                    x.AppointmentId ==
                    appointment.Id);

        if (existingPayment != null)
        {
            if (existingPayment.Status ==
                PaymentStatus.Paid)
            {
                BusinessRuleGuard.Against(
    existingPayment.Status ==
    PaymentStatus.Paid,
    "Appointment has already been paid.");
            }

            if (existingPayment.Status ==
                PaymentStatus.Refunded)
            {
                throw new BusinessException(
    "Refunded appointments require a new booking.");
            }

            if (existingPayment.Status ==
                PaymentStatus.Pending)
            {
                PaymentIntent existingPaymentIntent;

                try
                {
                    existingPaymentIntent =
                        await _stripeVerificationService
                            .GetPaymentIntentAsync(
                                existingPayment
                                    .StripePaymentIntentId);
                }
                catch (StripeException exception)
                {
                    throw new ExternalProviderException(
                        "Stripe",
                        "The existing refund could not be verified "
                        + "because the payment provider is temporarily unavailable. "
                        + "Please try again.",
                        exception);
                }

                var reusableStatuses =
                    new[]
                    {
                        "requires_payment_method",
                        "requires_confirmation",
                        "requires_action",
                        "processing",
                        "requires_capture"
                    };

                if (reusableStatuses.Any(status =>
                        string.Equals(
                            existingPaymentIntent.Status,
                            status,
                            StringComparison.OrdinalIgnoreCase)))
                {
                    return new PaymentIntentResponseDto
                    {
                        ClientSecret =
         existingPaymentIntent.ClientSecret,

                        PaymentIntentId =
         existingPaymentIntent.Id,

                        AppointmentId =
         appointment.Id,

                        Amount =
         existingPayment.Amount,

                        Currency =
         PaymentCurrency,

                        Purpose =
         $"Therapy appointment with "
         + $"{appointment.Therapist.User.FirstName} "
         + $"{appointment.Therapist.User.LastName}"
                    };
                }

                if (string.Equals(
                        existingPaymentIntent.Status,
                        "succeeded",
                        StringComparison.OrdinalIgnoreCase))
                {
                    return new PaymentIntentResponseDto
                    {
                        ClientSecret =
                            existingPaymentIntent.ClientSecret,

                        PaymentIntentId =
                            existingPaymentIntent.Id,

                        AppointmentId =
                            appointment.Id,

                        Amount =
                            existingPayment.Amount,

                        Currency =
                            PaymentCurrency,

                        Purpose =
                            $"Therapy appointment with "
                            + $"{appointment.Therapist.User.FirstName} "
                            + $"{appointment.Therapist.User.LastName}"
                    };
                }

                existingPayment.Status =
                    PaymentStatus.Failed;
            }
        }

        var amount =
            appointment.Therapist.HourlyRate;

        if (amount <= 0)
        {
            throw new Exception(
                "Appointment amount is invalid.");
        }

        var options =
            new PaymentIntentCreateOptions
            {
                Amount =
                    ConvertToMinorUnits(amount),

                Currency =
                    PaymentCurrency,

                AutomaticPaymentMethods =
                    new PaymentIntentAutomaticPaymentMethodsOptions
                    {
                        Enabled = true
                    },

                Metadata =
                    new Dictionary<string, string>
                    {
                        ["appointmentId"] =
                            appointment.Id.ToString(),

                        ["clientUserId"] =
                            clientUserId.ToString(),

                        ["clientId"] =
                            client.Id.ToString()
                    },

                Description =
                    $"MindBloom appointment {appointment.Id}"
            };

        var paymentIntentService =
            new PaymentIntentService(
                _stripeClientProvider.Client);

        var idempotencySource =
    existingPayment == null
        ? "initial"
        : $"after-{existingPayment.StripePaymentIntentId}";

        var requestOptions =
            new RequestOptions
            {
                IdempotencyKey =
                    $"mindbloom-appointment-payment-"
                    + $"{appointment.Id}-"
                    + idempotencySource
            };

        PaymentIntent paymentIntent;

        try
        {
            paymentIntent =
                await paymentIntentService
                    .CreateAsync(
                        options,
                        requestOptions);
        }
        catch (StripeException exception)
        {
            throw new ExternalProviderException(
                "Stripe",
                "The payment service is temporarily unavailable. "
                + "Payment was not started. Please try again.",
                exception);
        }

        if (existingPayment != null)
        {
            existingPayment.Amount =
                amount;

            existingPayment.Status =
                PaymentStatus.Pending;

            existingPayment.StripePaymentIntentId =
                paymentIntent.Id;

            existingPayment.PaidAtUtc =
                null;
        }
        else
        {
            var payment =
                new Payment
                {
                    AppointmentId =
                        appointment.Id,

                    Amount =
                        amount,

                    Status =
                        PaymentStatus.Pending,

                    StripePaymentIntentId =
                        paymentIntent.Id
                };

            _context.Payments.Add(payment);
        }

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException exception)
        {
            throw new BusinessException(
                "A payment already exists for this appointment or Stripe PaymentIntent.",
                exception);
        }

        return new PaymentIntentResponseDto
        {
            ClientSecret =
                paymentIntent.ClientSecret,

            PaymentIntentId =
                paymentIntent.Id,

            AppointmentId =
                appointment.Id,

            Amount =
                amount,

            Currency =
                PaymentCurrency,

            Purpose =
                $"Therapy appointment with "
                + $"{appointment.Therapist.User.FirstName} "
                + $"{appointment.Therapist.User.LastName}"
        };
    }

    public async Task ConfirmPaymentAsync(
        int clientUserId,
        ConfirmPaymentDto request)
    {

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var payment =
            await _context.Payments
                .Include(x => x.Appointment)
                .ThenInclude(x => x.Therapist)
                .FirstOrDefaultAsync(x =>
                    x.StripePaymentIntentId ==
                    request.PaymentIntentId);

        if (payment == null)
        {
            throw new NotFoundException(
                "Payment not found.");
        }

        if (payment.Appointment.ClientId !=
            client.Id)
        {
            BusinessRuleGuard.AgainstNotOwned(
    payment.Appointment.ClientId ==
    client.Id,
    "This payment does not belong to you.");
        }

        if (payment.Status ==
            PaymentStatus.Refunded)
        {
            throw new BusinessException(
                "This payment has already been refunded.");
        }

        if (payment.Status ==
            PaymentStatus.Paid)
        {
            if (!payment.Appointment.IsPaid)
            {
                payment.Appointment.IsPaid =
                    true;

                await _context.SaveChangesAsync();
            }

            return;
        }

        var anotherPaidPaymentExists =
            await _context.Payments
                .AnyAsync(x =>
                    x.Id != payment.Id &&
                    x.AppointmentId ==
                    payment.AppointmentId &&
                    x.Status ==
                    PaymentStatus.Paid);

        if (anotherPaidPaymentExists)
        {
            BusinessRuleGuard.Against(
    anotherPaidPaymentExists,
    "Appointment already has a completed payment.");
        }

        PaymentIntent stripePaymentIntent;

        try
        {
            stripePaymentIntent =
                await _stripeVerificationService
                    .GetPaymentIntentAsync(
                        request.PaymentIntentId);
        }
        catch (StripeException exception)
        {
            throw new ExternalProviderException(
                "Stripe",
                "The payment could not be verified because "
                + "the payment provider is temporarily unavailable. "
                + "Please try again.",
                exception);
        }

        if (!string.Equals(
                stripePaymentIntent.Id,
                payment.StripePaymentIntentId,
                StringComparison.Ordinal))
        {
            throw new Exception(
                "Stripe payment reference does not match.");
        }

        if (!string.Equals(
                stripePaymentIntent.Status,
                "succeeded",
                StringComparison.OrdinalIgnoreCase))
        {
            throw new Exception(
                $"Stripe payment has not succeeded. "
                + $"Current status: {stripePaymentIntent.Status}.");
        }

        var expectedAmount =
            ConvertToMinorUnits(
                payment.Amount);

        if (stripePaymentIntent.Amount !=
            expectedAmount)
        {
            throw new Exception(
                "Stripe payment amount does not match the expected appointment amount.");
        }

        if (!string.Equals(
                stripePaymentIntent.Currency,
                PaymentCurrency,
                StringComparison.OrdinalIgnoreCase))
        {
            throw new Exception(
                "Stripe payment currency does not match the expected currency.");
        }

        ValidateMetadata(
            stripePaymentIntent,
            payment,
            clientUserId,
            client.Id);

        payment.Status =
     PaymentStatus.Paid;

        payment.PaidAtUtc ??=
            DateTime.UtcNow;

        payment.Appointment.IsPaid =
            true;

        var paymentSucceededEvent =
            new PaymentSucceededEvent
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

                PaidAtUtc =
                    payment.PaidAtUtc
                    ?? DateTime.UtcNow
            };

        await _outboxWriter
            .EnqueueAsync(
                paymentSucceededEvent,
                IntegrationEventRoutingKeys
                    .PaymentSucceeded);

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException exception)
        {
            _context.ChangeTracker.Clear();

            var confirmedPayment =
                await _context.Payments
                    .AsNoTracking()
                    .FirstOrDefaultAsync(x =>
                        x.StripePaymentIntentId ==
                            request.PaymentIntentId);

            if (confirmedPayment?.Status ==
                PaymentStatus.Paid)
            {
                return;
            }

            throw new Exception(
                "Payment confirmation could not be completed.",
                exception);
        }

        await _businessNotificationService
            .PublishAsync(
                clientUserId,
                "Payment completed",
                $"Your payment of "
                + $"{payment.Amount:F2} "
                + $"{PaymentCurrency.ToUpperInvariant()} "
                + "was completed successfully.",
                payment.AppointmentId,
                NotificationActionType.Payment);
    }

    public async Task<List<PaymentHistoryDto>>
    GetMyPaymentsAsync(
        int clientUserId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var appointmentPayments =
            await _context.Payments
                .AsNoTracking()
                .Include(x => x.Appointment)
                    .ThenInclude(x => x.Therapist)
                        .ThenInclude(x => x.User)
                .Where(x =>
                    x.Appointment.ClientId ==
                        client.Id &&
                    !x.IsDeleted)
                .Select(x =>
                    new PaymentHistoryDto
                    {
                        Id =
                            x.Id,

                        PaymentType =
                            "Appointment",

                        AppointmentId =
                            x.AppointmentId,

                        MembershipId =
                            null,

                        Amount =
                            x.Amount,

                        Currency =
                            PaymentCurrency
                                .ToUpperInvariant(),

                        Purpose =
                            "Therapy appointment with "
                            + x.Appointment
                                .Therapist.User.FirstName
                            + " "
                            + x.Appointment
                                .Therapist.User.LastName,

                        Status =
                            x.Status.ToString(),

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        PaidAtUtc =
                            x.PaidAtUtc,

                        TherapistName =
                            x.Appointment
                                .Therapist.User.FirstName
                            + " "
                            + x.Appointment
                                .Therapist.User.LastName,

                        RefundReason =
                            x.RefundReason,

                        RefundRequestedAtUtc =
                            x.RefundRequestedAtUtc,

                        RefundedAtUtc =
                            x.RefundedAtUtc,

                        RefundFailureReason =
                            x.RefundFailureReason
                    })
                .ToListAsync();

        var membershipPayments =
            await _context.MembershipPayments
                .AsNoTracking()
                .Include(x =>
                    x.ClientMembership)
                    .ThenInclude(x =>
                        x.Therapist)
                        .ThenInclude(x =>
                            x.User)
                .Where(x =>
                    x.ClientMembership.ClientId ==
                        client.Id &&
                    !x.IsDeleted &&
                    !x.ClientMembership.IsDeleted)
                .Select(x =>
                    new PaymentHistoryDto
                    {
                        Id =
                            x.Id,

                        PaymentType =
                            "Membership",

                        AppointmentId =
                            null,

                        MembershipId =
                            x.ClientMembershipId,

                        Amount =
                            x.Amount,

                        Currency =
                            x.Currency
                                .ToUpper(),

                        Purpose =
                            x.ClientMembership.PlanType
                                .ToString()
                            + " membership with "
                            + x.ClientMembership
                                .Therapist.User.FirstName
                            + " "
                            + x.ClientMembership
                                .Therapist.User.LastName,

                        Status =
                            x.Status.ToString(),

                        CreatedAtUtc =
                            x.CreatedAtUtc,

                        PaidAtUtc =
                            x.PaidAtUtc,

                        TherapistName =
                            x.ClientMembership
                                .Therapist.User.FirstName
                            + " "
                            + x.ClientMembership
                                .Therapist.User.LastName,

                        RefundReason =
                            null,

                        RefundRequestedAtUtc =
                            null,

                        RefundedAtUtc =
                            null,

                        RefundFailureReason =
                            null
                    })
                .ToListAsync();

        return appointmentPayments
            .Concat(membershipPayments)
            .OrderByDescending(x =>
                x.PaidAtUtc ??
                x.CreatedAtUtc)
            .ToList();
    }

    public async Task<PaymentReceiptDto>
        GetReceiptAsync(
            int paymentId,
            int clientUserId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                    clientUserId);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var payment =
            await _context.Payments
            .AsNoTracking()
                .Include(x => x.Appointment)
                .ThenInclude(x => x.Therapist)
                .ThenInclude(x => x.User)
                .Include(x => x.Appointment)
                .ThenInclude(x => x.Client)
                .ThenInclude(x => x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id == paymentId &&
                    x.Appointment.ClientId ==
                    client.Id);

        if (payment == null)
        {
            throw new NotFoundException(
                "Payment not found.");
        }

        return new PaymentReceiptDto
        {
            PaymentId =
                payment.Id,

            Amount =
                payment.Amount,

            Status =
                payment.Status.ToString(),

            PaymentDateUtc =
                payment.PaidAtUtc ??
                payment.CreatedAtUtc,

            AppointmentId =
                payment.AppointmentId,

            AppointmentStartUtc =
                payment.Appointment.StartUtc,

            AppointmentEndUtc =
                payment.Appointment.EndUtc,

            TherapistName =
                payment.Appointment
                    .Therapist
                    .User
                    .FirstName
                + " "
                + payment.Appointment
                    .Therapist
                    .User
                    .LastName,

            ClientName =
                payment.Appointment
                    .Client
                    .User
                    .FirstName
                + " "
                + payment.Appointment
                    .Client
                    .User
                    .LastName,

            InvoiceNumber =
                $"INV-{payment.Id:D6}",

            Currency =
    PaymentCurrency.ToUpperInvariant(),

            Purpose =
    "Therapy appointment with "
    + payment.Appointment
        .Therapist.User.FirstName
    + " "
    + payment.Appointment
        .Therapist.User.LastName,

            StripePaymentIntentId =
    payment.StripePaymentIntentId,

            StripeRefundId =
    payment.StripeRefundId,

            RefundReason =
    payment.RefundReason,

            RefundRequestedAtUtc =
    payment.RefundRequestedAtUtc,

            RefundedAtUtc =
    payment.RefundedAtUtc,

            RefundFailureReason =
    payment.RefundFailureReason,
        };
    }

    public async Task
     RefundAppointmentPaymentAsync(
         int clientUserId,
         int appointmentId,
         string reason)
    {
        var normalizedReason = reason?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(normalizedReason))
        {
            throw new BusinessException(
    "Refund reason is required.");
        }

        if (normalizedReason.Length > 500)
        {
            throw new BusinessException(
     "Refund reason may contain at most 500 characters.");
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId ==
                        clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new NotFoundException(
                "Client not found.");
        }

        var payment =
            await _context.Payments
                .Include(x =>
                    x.Appointment)
                .FirstOrDefaultAsync(x =>
                    x.AppointmentId ==
                        appointmentId &&
                    x.Appointment.ClientId ==
                        client.Id);

        if (payment == null)
        {
            return;
        }

        if (payment.Status ==
            PaymentStatus.Refunded)
        {
            if (payment.Appointment.IsPaid)
            {
                payment.Appointment.IsPaid =
                    false;

                await _context.SaveChangesAsync();
            }

            return;
        }

        if (payment.Status ==
            PaymentStatus.RefundPending)
        {

            if (!string.IsNullOrWhiteSpace(
                    payment.StripeRefundId))
            {
                var existingRefundService =
                    new RefundService(
                        _stripeClientProvider.Client);

                Refund existingRefund;

                try
                {
                    existingRefund =
                        await existingRefundService
                            .GetAsync(
                                payment
                                    .StripeRefundId);
                }
                catch (StripeException exception)
                {
                    throw new ExternalProviderException(
                        "Stripe",
                        "The payment service is temporarily unavailable. "
                        + "Please try again.",
                        exception);
                }

                if (string.Equals(
        existingRefund.Status,
        "succeeded",
        StringComparison.OrdinalIgnoreCase))
                {
                    payment.Status =
                        PaymentStatus.Refunded;

                    payment.RefundedAtUtc ??=
                        DateTime.UtcNow;

                    payment.RefundFailureReason =
                        null;

                    payment.Appointment.IsPaid =
                        false;

                    await EnqueuePaymentRefundedEventAsync(
                        payment,
                        clientUserId,
                        cancellationReason:
                            payment.RefundReason);

                    await _context.SaveChangesAsync();

                    await _businessNotificationService
                        .PublishAsync(
                            clientUserId,
                            "Payment refunded",
                            $"Your payment of "
                            + $"{payment.Amount:F2} "
                            + $"{PaymentCurrency.ToUpperInvariant()} "
                            + "has been refunded.",
                            payment.AppointmentId,
                            NotificationActionType.Payment);

                    return;
                }

                if (string.Equals(
                        existingRefund.Status,
                        "pending",
                        StringComparison
                            .OrdinalIgnoreCase) ||
                    string.Equals(
                        existingRefund.Status,
                        "requires_action",
                        StringComparison
                            .OrdinalIgnoreCase))
                {
                    return;
                }

                payment.Status =
                    PaymentStatus.RefundFailed;

                payment.RefundFailureReason =
                    existingRefund
                        .FailureReason ??
                    $"Stripe refund status: "
                    + $"{existingRefund.Status}";

                await _context
                    .SaveChangesAsync();
            }
        }

        if (payment.Status !=
                PaymentStatus.Paid &&
            payment.Status !=
                PaymentStatus.RefundFailed &&
            payment.Status !=
                PaymentStatus.RefundPending)
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(
                payment
                    .StripePaymentIntentId))
        {
            throw new Exception(
                "Stripe payment reference is missing.");
        }

        PaymentIntent stripePaymentIntent;

        try
        {
            stripePaymentIntent =
                await _stripeVerificationService
                    .GetPaymentIntentAsync(
                        payment
                            .StripePaymentIntentId);
        }
        catch (StripeException exception)
        {
            throw new ExternalProviderException(
                "Stripe",
                "The payment could not be verified for refund "
                + "because the payment provider is temporarily unavailable. "
                + "Please try again.",
                exception);
        }

        if (!string.Equals(
                stripePaymentIntent.Status,
                "succeeded",
                StringComparison
                    .OrdinalIgnoreCase))
        {
            throw new Exception(
                "Only a successfully charged Stripe payment can be refunded.");
        }

        if (stripePaymentIntent.AmountReceived <= 0)
        {
            throw new Exception(
                "Stripe payment does not contain a refundable charged amount.");
        }

        var expectedAmount =
            ConvertToMinorUnits(
                payment.Amount);

        if (stripePaymentIntent
                .AmountReceived !=
            expectedAmount)
        {
            throw new Exception(
                "Stripe charged amount does not match the recorded payment amount.");
        }

      

        payment.Status =
            PaymentStatus.RefundPending;

        payment.RefundReason =
            normalizedReason;

        payment.RefundRequestedAtUtc ??=
            DateTime.UtcNow;

        payment.RefundFailureReason =
            null;

        await _context.SaveChangesAsync();

        var refundService =
            new RefundService(
                _stripeClientProvider.Client);

        var refundOptions =
            new RefundCreateOptions
            {
                PaymentIntent =
                    payment
                        .StripePaymentIntentId,

                Amount =
                    stripePaymentIntent
                        .AmountReceived,

                Reason =
                    RefundReasons
                        .RequestedByCustomer,

                Metadata =
                    new Dictionary<string, string>
                    {
                        ["paymentId"] =
                            payment.Id
                                .ToString(),

                        ["appointmentId"] =
                            appointmentId
                                .ToString(),

                        ["clientUserId"] =
                            clientUserId
                                .ToString(),

                        ["cancellationReason"] =
                            normalizedReason
                    }
            };

        var requestOptions =
            new RequestOptions
            {
                IdempotencyKey =
                    $"mindbloom-refund-payment-{payment.Id}"
            };

        Refund stripeRefund;

        try
        {
            stripeRefund =
                await refundService
                    .CreateAsync(
                        refundOptions,
                        requestOptions);
        }
        catch (StripeException exception)
        {
            payment.Status =
                PaymentStatus.RefundFailed;

            payment.RefundFailureReason =
                exception.StripeError
                    ?.Message ??
                exception.Message;

            await _context
                .SaveChangesAsync();

            throw new ExternalProviderException(
                "Stripe",
                "The refund could not be completed because "
                + "the payment provider is temporarily unavailable. "
                + "Please try again.",
                exception);
        }

        payment.StripeRefundId =
            stripeRefund.Id;

        var refundCompleted = false;

        if (string.Equals(
                stripeRefund.Status,
                "succeeded",
                StringComparison
                    .OrdinalIgnoreCase))
        {
            payment.Status =
                PaymentStatus.Refunded;

            payment.RefundedAtUtc =
                DateTime.UtcNow;

            payment.RefundFailureReason =
                null;

            payment.Appointment.IsPaid =
                false;

            refundCompleted = true;

        }
        else if (string.Equals(
                     stripeRefund.Status,
                     "pending",
                     StringComparison
                         .OrdinalIgnoreCase) ||
                 string.Equals(
                     stripeRefund.Status,
                     "requires_action",
                     StringComparison
                         .OrdinalIgnoreCase))
        {
            payment.Status =
                PaymentStatus.RefundPending;
        }
        else
        {
            payment.Status =
                PaymentStatus.RefundFailed;

            payment.RefundFailureReason =
                stripeRefund
                    .FailureReason ??
                $"Stripe refund status: "
                + $"{stripeRefund.Status}";
        }

        if (refundCompleted)
        {
            await EnqueuePaymentRefundedEventAsync(
                payment,
                clientUserId,
                cancellationReason:
                    normalizedReason);
        }

        await _context.SaveChangesAsync();

        if (refundCompleted)
        {

            await _businessNotificationService
                .PublishAsync(
                    clientUserId,
                    "Payment refunded",
                    $"Your payment of "
                    + $"{payment.Amount:F2} "
                    + $"{PaymentCurrency.ToUpperInvariant()} "
                    + "has been refunded.",
                    payment.AppointmentId,
                    NotificationActionType.Payment);
        }
    }

    private Task EnqueuePaymentRefundedEventAsync(
      Payment payment,
      int clientUserId,
      string? cancellationReason,
      CancellationToken cancellationToken =
          default)
    {
        if (payment.Status !=
            PaymentStatus.Refunded)
        {
            throw new InvalidOperationException(
                "PaymentRefundedEvent can only be created for a refunded payment.");
        }

        var paymentRefundedEvent =
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
                    string.IsNullOrWhiteSpace(
                        cancellationReason)
                        ? payment.RefundReason
                        : cancellationReason.Trim(),

                RefundedAtUtc =
                    payment.RefundedAtUtc
                    ?? DateTime.UtcNow
            };

        return _outboxWriter.EnqueueAsync(
            paymentRefundedEvent,
            IntegrationEventRoutingKeys
                .PaymentRefunded,
            cancellationToken,
            idempotencyKey:
                $"payment-refunded:{payment.Id}");
    }

    private static void ValidateMetadata(
        PaymentIntent stripePaymentIntent,
        Payment payment,
        int clientUserId,
        int clientId)
    {
        if (stripePaymentIntent.Metadata ==
            null)
        {
            throw new Exception(
                "Stripe payment metadata is missing.");
        }

        if (!stripePaymentIntent.Metadata
                .TryGetValue(
                    "appointmentId",
                    out var appointmentIdValue) ||
            !int.TryParse(
                appointmentIdValue,
                out var appointmentId))
        {
            throw new Exception(
                "Stripe appointment metadata is missing or invalid.");
        }

        if (appointmentId !=
            payment.AppointmentId)
        {
            throw new Exception(
                "Stripe payment is linked to a different appointment.");
        }

        if (!stripePaymentIntent.Metadata
                .TryGetValue(
                    "clientUserId",
                    out var clientUserIdValue) ||
            !int.TryParse(
                clientUserIdValue,
                out var metadataClientUserId))
        {
            throw new Exception(
                "Stripe client user metadata is missing or invalid.");
        }

        if (metadataClientUserId !=
            clientUserId)
        {
            throw new Exception(
                "Stripe payment is linked to a different user.");
        }

        if (!stripePaymentIntent.Metadata
                .TryGetValue(
                    "clientId",
                    out var clientIdValue) ||
            !int.TryParse(
                clientIdValue,
                out var metadataClientId))
        {
            throw new Exception(
                "Stripe client metadata is missing or invalid.");
        }

        if (metadataClientId != clientId)
        {
            throw new Exception(
                "Stripe payment is linked to a different client profile.");
        }
    }

    private static long ConvertToMinorUnits(
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