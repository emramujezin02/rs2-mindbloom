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
                .FirstOrDefaultAsync(
                    x =>
                        x.StripePaymentIntentId
                        == request.PaymentIntentId);

        if (payment == null)
        {
            throw new Exception("Payment not found.");
        }

        payment.Status = PaymentStatus.Paid;

        payment.PaidAtUtc = DateTime.Now;

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
}