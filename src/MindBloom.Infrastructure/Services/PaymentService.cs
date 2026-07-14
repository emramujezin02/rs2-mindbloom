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
    private const string PaymentCurrency =
        "usd";

    private readonly ApplicationDbContext
        _context;

    private readonly StripeVerificationService
        _stripeVerificationService;

    public PaymentService(
        ApplicationDbContext context,
        StripeVerificationService
            stripeVerificationService)
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
                    x.UserId ==
                    clientUserId &&
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
                    x.Id ==
                    request.AppointmentId);

        if (appointment == null)
        {
            throw new Exception(
                "Appointment not found.");
        }

        if (appointment.ClientId !=
            client.Id)
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

        var existingPaidPayment =
            await _context.Payments
                .AnyAsync(x =>
                    x.AppointmentId ==
                        appointment.Id &&
                    x.Status ==
                        PaymentStatus.Paid);

        if (existingPaidPayment)
        {
            throw new Exception(
                "This appointment is already paid.");
        }

        var amount =
            appointment.Therapist
                .HourlyRate;

        if (amount <= 0)
        {
            throw new Exception(
                "Appointment amount is invalid.");
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

        var options =
            new PaymentIntentCreateOptions
            {
                Amount =
                    ConvertToMinorUnits(
                        amount),

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
                            appointment.Id
                                .ToString(),

                        ["clientUserId"] =
                            clientUserId
                                .ToString(),

                        ["clientId"] =
                            client.Id
                                .ToString()
                    },

                Description =
                    $"MindBloom appointment "
                    + $"{appointment.Id}"
            };

        var paymentIntentService =
            new PaymentIntentService();

        var paymentIntent =
            await paymentIntentService
                .CreateAsync(options);

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

        _context.Payments.Add(
            payment);

        await _context.SaveChangesAsync();

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
                .ThenInclude(x =>
                    x.Therapist)
                .FirstOrDefaultAsync(x =>
                    x.StripePaymentIntentId ==
                    request.PaymentIntentId);

        if (payment == null)
        {
            throw new Exception(
                "Payment not found.");
        }

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

        if (payment.Status ==
                PaymentStatus.Paid &&
            payment.Appointment.IsPaid)
        {
            return;
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

        if (stripePaymentIntent.Id !=
            payment.StripePaymentIntentId)
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
                + $"Current status: "
                + $"{stripePaymentIntent.Status}.");
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

        payment.PaidAtUtc =
            DateTime.UtcNow;

        payment.Appointment.IsPaid =
            true;

        await _context.SaveChangesAsync();
    }

    public async Task<List<PaymentHistoryDto>>
        GetMyPaymentsAsync(
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

        return await _context.Payments
            .Include(x => x.Appointment)
                .ThenInclude(x =>
                    x.Therapist)
                    .ThenInclude(x =>
                        x.User)
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
                .Include(x =>
                    x.Appointment)
                    .ThenInclude(x =>
                        x.Therapist)
                        .ThenInclude(x =>
                            x.User)
                .Include(x =>
                    x.Appointment)
                    .ThenInclude(x =>
                        x.Client)
                        .ThenInclude(x =>
                            x.User)
                .FirstOrDefaultAsync(x =>
                    x.Id ==
                        paymentId &&
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
                payment.Appointment
                    .StartUtc,

            AppointmentEndUtc =
                payment.Appointment
                    .EndUtc,

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
            return;
        }

        if (payment.Status !=
            PaymentStatus.Paid)
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

        var refundService =
            new RefundService();

        var refundOptions =
            new RefundCreateOptions
            {
                PaymentIntent =
                    payment
                        .StripePaymentIntentId,

                Reason =
                    RefundReasons
                        .RequestedByCustomer,

                Metadata =
                    new Dictionary<string, string>
                    {
                        ["appointmentId"] =
                            appointmentId
                                .ToString(),

                        ["clientUserId"] =
                            clientUserId
                                .ToString(),

                        ["cancellationReason"] =
                            reason
                    }
            };

        var stripeRefund =
            await refundService
                .CreateAsync(
                    refundOptions);

        if (!string.Equals(
                stripeRefund.Status,
                "succeeded",
                StringComparison
                    .OrdinalIgnoreCase) &&
            !string.Equals(
                stripeRefund.Status,
                "pending",
                StringComparison
                    .OrdinalIgnoreCase))
        {
            throw new Exception(
                "Stripe refund could not be initiated.");
        }

        payment.Status =
            PaymentStatus.Refunded;

        payment.Appointment.IsPaid =
            false;

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

        if (metadataClientId !=
            clientId)
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