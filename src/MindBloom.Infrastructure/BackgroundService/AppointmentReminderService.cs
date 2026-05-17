using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Enums;

namespace MindBloom.Infrastructure.BackgroundServices;

public class AppointmentReminderService
    : BackgroundService
{
    private readonly IServiceScopeFactory
        _scopeFactory;

    public AppointmentReminderService(
        IServiceScopeFactory scopeFactory)
    {
        _scopeFactory = scopeFactory;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope =
                _scopeFactory.CreateScope();

            var context =
                scope.ServiceProvider
                    .GetRequiredService<
                        ApplicationDbContext>();

            var emailService =
                scope.ServiceProvider
                    .GetRequiredService<
                        IEmailService>();

            var now =
                DateTime.UtcNow;

            var tomorrow =
                now.AddHours(24);

            var appointments =
                await context.Appointments
                    .Include(x => x.Client)
                        .ThenInclude(x => x.User)
                    .Include(x => x.Therapist)
                        .ThenInclude(x => x.User)
                    .Where(x =>
                        !x.ReminderSent
                        && x.Status
                            == AppointmentStatus.Accepted
                        && x.StartUtc <= tomorrow
                        && x.StartUtc > now)
                    .ToListAsync();

            foreach (var appointment
                     in appointments)
            {
                var clientEmail =
                    appointment.Client
                        .User.Email!;

                var therapistEmail =
                    appointment.Therapist
                        .User.Email!;

                var subject =
                    "Appointment Reminder";

                var message =
                    $"""
                    Reminder:

                    You have an appointment scheduled
                    on {appointment.StartUtc} UTC.
                    """;

                await emailService.SendAsync(
                    clientEmail,
                    subject,
                    message);

                await emailService.SendAsync(
                    therapistEmail,
                    subject,
                    message);

                appointment.ReminderSent = true;
            }

            await context.SaveChangesAsync();

            await Task.Delay(
                TimeSpan.FromHours(1),
                stoppingToken);
        }
    }
}