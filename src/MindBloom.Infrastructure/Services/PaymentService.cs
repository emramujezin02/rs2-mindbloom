using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;

namespace MindBloom.Infrastructure.Services;

public class PaymentService : IPaymentService
{
    private const string PaymentCurrency = "usd";

    private readonly ApplicationDbContext _context;

    private readonly StripeVerificationService
        _stripeVerificationService;

    public PaymentService(
        ApplicationDbContext context,
        StripeVerificationService stripeVerificationService)
    {
        _context = context;

        _stripeVerificationService =
            stripeVerificationService;
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
            throw new Exception(
                "Client not found.");
        }

        var appointment =
            await _context.Appointments
                .Include(x => x.Therapist)
                .FirstOrDefaultAsync(x =>
                    x.Id == request.AppointmentId);

        if (appointment == null)
        {
            throw new Exception(
                "Appointment not found.");
        }

        if (appointment.ClientId != client.Id)
        {
            throw new Exception(
                "This appointment does not belong to you.");
        }

        if (appointment.Status !=
            AppointmentStatus.Accepted)
        {
            throw new Exception(
                "Only accepted appointments can be paid.");
        }

        if (appointment.IsPaid)
        {
            throw new Exception(
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
                throw new Exception(
                    "Appointment has already been paid.");
            }

            if (existingPayment.Status ==
                PaymentStatus.Refunded)
            {
                throw new Exception(
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
                    throw new Exception(
                        "Existing payment could not be verified with Stripe.",
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
                            existingPaymentIntent.Id
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
                            existingPaymentIntent.Id
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

        var secretKey =
            Environment.GetEnvironmentVariable(
                "STRIPE_SECRET_KEY");

        if (string.IsNullOrWhiteSpace(secretKey))
        {
            throw new Exception(
                "Stripe configuration is missing.");
        }

        StripeConfiguration.ApiKey =
            secretKey;

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
            new PaymentIntentService();

        var paymentIntent =
            await paymentIntentService
                .CreateAsync(options);

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
            throw new Exception(
                "A payment already exists for this appointment or Stripe PaymentIntent.",
                exception);
        }

        return new PaymentIntentResponseDto
        {
            ClientSecret =
                paymentIntent.ClientSecret,

            PaymentIntentId =
                paymentIntent.Id
        };
    }

    public async Task ConfirmPaymentAsync(
        int clientUserId,
        ConfirmPaymentDto request)
    {
        if (string.IsNullOrWhiteSpace(
                request.PaymentIntentId))
        {
            throw new Exception(
                "Payment intent ID is required.");
        }

        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId &&
                    !x.IsDeleted);

        if (client == null)
        {
            throw new Exception(
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
            throw new Exception(
                "Payment not found.");
        }

        /*
         * Provjera vlasništva mora biti prije
         * idempotentnog returna.
         */
        if (payment.Appointment.ClientId !=
            client.Id)
        {
            throw new Exception(
                "This payment does not belong to you.");
        }

        if (payment.Status ==
            PaymentStatus.Refunded)
        {
            throw new Exception(
                "This payment has already been refunded.");
        }

        /*
         * Idempotentni rezultat:
         * ako je payment već evidentiran kao plaćen,
         * ne izvršavaju se ponovo nikakvi efekti.
         */
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
            throw new Exception(
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
            throw new Exception(
                "Payment could not be verified with Stripe.",
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

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateException exception)
        {
            /*
             * U slučaju paralelnih confirm zahtjeva
             * ponovo provjeravamo stanje iz baze.
             */
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
    }

    public async Task<List<PaymentHistoryDto>>
        GetMyPaymentsAsync(
            int clientUserId)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(x =>
                    x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception(
                "Client not found.");
        }

        return await _context.Payments
            .Include(x => x.Appointment)
            .ThenInclude(x => x.Therapist)
            .ThenInclude(x => x.User)
            .Where(x =>
                x.Appointment.ClientId ==
                client.Id)
            .OrderByDescending(x =>
                x.CreatedAtUtc)
            .Select(x =>
                new PaymentHistoryDto
                {
                    Id =
                        x.Id,

                    Amount =
                        x.Amount,

                    Status =
                        x.Status.ToString(),

                    CreatedAtUtc =
                        x.CreatedAtUtc,

                    AppointmentId =
                        x.AppointmentId,

                    TherapistName =
                        x.Appointment
                            .Therapist
                            .User
                            .FirstName
                        + " "
                        + x.Appointment
                            .Therapist
                            .User
                            .LastName
                })
            .ToListAsync();
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
            throw new Exception(
                "Client not found.");
        }

        var payment =
            await _context.Payments
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
            throw new Exception(
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
                $"INV-{payment.Id:D6}"
        };
    }

    public async Task
     RefundAppointmentPaymentAsync(
         int clientUserId,
         int appointmentId,
         string reason)
    {
        var normalizedReason =
            reason?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(
                normalizedReason))
        {
            throw new Exception(
                "Refund reason is required.");
        }

        if (normalizedReason.Length > 500)
        {
            throw new Exception(
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
            throw new Exception(
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

        /*
         * Termin možda nije plaćen.
         * U tom slučaju otkazivanje se može nastaviti
         * bez refundiranja.
         */
        if (payment == null)
        {
            return;
        }

        /*
         * Idempotentni rezultat:
         * refund je već završen i ne šaljemo
         * novi zahtjev Stripeu.
         */
        if (payment.Status ==
            PaymentStatus.Refunded)
        {
            if (payment.Appointment.IsPaid)
            {
                payment.Appointment.IsPaid =
                    false;

                await _context
                    .SaveChangesAsync();
            }

            return;
        }

        if (payment.Status ==
            PaymentStatus.RefundPending)
        {
            /*
             * Ako već imamo Stripe refund ID,
             * provjeravamo njegov stvarni status.
             */
            if (!string.IsNullOrWhiteSpace(
                    payment.StripeRefundId))
            {
                var existingRefundService =
                    new RefundService();

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
                    throw new Exception(
                        "Existing Stripe refund could not be verified.",
                        exception);
                }

                if (string.Equals(
                        existingRefund.Status,
                        "succeeded",
                        StringComparison
                            .OrdinalIgnoreCase))
                {
                    payment.Status =
                        PaymentStatus.Refunded;

                    payment.RefundedAtUtc ??=
                        DateTime.UtcNow;

                    payment
                        .RefundFailureReason =
                        null;

                    payment.Appointment.IsPaid =
                        false;

                    await _context
                        .SaveChangesAsync();

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
                PaymentStatus.RefundFailed)
        {
            /*
             * Pending ili Failed uplata nije
             * stvarno naplaćena i nema šta
             * refundirati.
             */
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
            throw new Exception(
                "Stripe payment could not be verified before refund.",
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

        var secretKey =
            Environment.GetEnvironmentVariable(
                "STRIPE_SECRET_KEY");

        if (string.IsNullOrWhiteSpace(
                secretKey))
        {
            throw new Exception(
                "Stripe configuration is missing.");
        }

        StripeConfiguration.ApiKey =
            secretKey;

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
            new RefundService();

        var refundOptions =
            new RefundCreateOptions
            {
                PaymentIntent =
                    payment
                        .StripePaymentIntentId,

                /*
                 * Refundiramo stvarni iznos koji je
                 * Stripe evidentirao kao naplaćen.
                 */
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

        /*
         * Deterministički idempotency key:
         * ponavljanje zahtjeva za isti Payment
         * ne smije napraviti drugi refund.
         */
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

            throw new Exception(
                "Stripe refund could not be created.",
                exception);
        }

        payment.StripeRefundId =
            stripeRefund.Id;

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

        await _context.SaveChangesAsync();
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