using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.Payments.DTOs;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using Stripe;

namespace MindBloom.Infrastructure.Services;

public class PaymentService : IPaymentService
{
    private readonly ApplicationDbContext _context;

    public PaymentService(
        ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<PaymentIntentResponseDto>
        CreatePaymentIntentAsync(
            int clientUserId,
            CreatePaymentIntentDto request)
    {
        var client =
            await _context.Clients
                .FirstOrDefaultAsync(
                    x => x.UserId == clientUserId);

        if (client == null)
        {
            throw new Exception("Client not found.");
        }

        var appointment =
            await _context.Appointments
                .Include(x => x.Therapist)
                .FirstOrDefaultAsync(
                    x => x.Id == request.AppointmentId);

        if (appointment == null)
        {
            throw new Exception("Appointment not found.");
        }

        if (appointment.Status
    != AppointmentStatus.Accepted)
        {
            throw new Exception(
                "Only accepted appointments can be paid.");
        }

        if (appointment.ClientId != client.Id)
        {
            throw new Exception(
                "This appointment does not belong to you.");
        }

        var amount =
            appointment.Therapist.HourlyRate;

        StripeConfiguration.ApiKey =
            Environment.GetEnvironmentVariable(
                "STRIPE_SECRET_KEY");

        var options = new PaymentIntentCreateOptions
        {
            Amount = (long)(amount * 100),
            Currency = "usd",
            AutomaticPaymentMethods =
                new PaymentIntentAutomaticPaymentMethodsOptions
                {
                    Enabled = true
                }
        };

        var service = new PaymentIntentService();

        var paymentIntent =
            await service.CreateAsync(options);

        var payment = new Payment
        {
            AppointmentId = appointment.Id,
            Amount = amount,
            Status = PaymentStatus.Pending,
            StripePaymentIntentId =
                paymentIntent.Id
        };

        _context.Payments.Add(payment);

        await _context.SaveChangesAsync();

        return new PaymentIntentResponseDto
        {
            ClientSecret = paymentIntent.ClientSecret,
            PaymentIntentId = paymentIntent.Id
        };
    }

    public async Task ConfirmPaymentAsync(
        ConfirmPaymentDto request)
    {
        var payment =
    await _context.Payments
        .Include(x => x.Appointment)
        .FirstOrDefaultAsync(x =>
            x.StripePaymentIntentId ==
                request.PaymentIntentId);

        if (payment == null)
        {
            throw new Exception("Payment not found.");
        }

        payment.Status = PaymentStatus.Paid;

        payment.PaidAtUtc = DateTime.UtcNow;

        payment.Appointment.IsPaid = true;

        await _context.SaveChangesAsync();
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
                x.Appointment.ClientId
                    == client.Id)
            .OrderByDescending(x =>
                x.CreatedAtUtc)
            .Select(x => new PaymentHistoryDto
            {
                Id = x.Id,

                Amount = x.Amount,

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
                    x.UserId == clientUserId);

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
                    x.Id == paymentId
                    && x.Appointment.ClientId
                        == client.Id);

        if (payment == null)
        {
            throw new Exception(
                "Payment not found.");
        }

        return new PaymentReceiptDto
        {
            PaymentId = payment.Id,

            Amount = payment.Amount,

            Status =
                payment.Status.ToString(),

            PaymentDateUtc =
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

    public async Task RefundAppointmentPaymentAsync(
    int clientUserId,
    int appointmentId,
    string reason)
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

        var payment =
            await _context.Payments
                .Include(x => x.Appointment)
                .FirstOrDefaultAsync(x =>
                    x.AppointmentId == appointmentId &&
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
                payment.StripePaymentIntentId))
        {
            throw new Exception(
                "Stripe payment reference is missing.");
        }

        StripeConfiguration.ApiKey =
            Environment.GetEnvironmentVariable(
                "STRIPE_SECRET_KEY");

        if (string.IsNullOrWhiteSpace(
                StripeConfiguration.ApiKey))
        {
            throw new Exception(
                "Stripe configuration is missing.");
        }

        var refundService =
            new RefundService();

        var refundOptions =
            new RefundCreateOptions
            {
                PaymentIntent =
                    payment.StripePaymentIntentId,
                Reason =
                    RefundReasons.RequestedByCustomer,
                Metadata =
                    new Dictionary<string, string>
                    {
                        ["appointmentId"] =
                            appointmentId.ToString(),
                        ["cancellationReason"] =
                            reason
                    }
            };

        var stripeRefund =
            await refundService.CreateAsync(
                refundOptions);

        if (stripeRefund.Status !=
                "succeeded" &&
            stripeRefund.Status !=
                "pending")
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
}