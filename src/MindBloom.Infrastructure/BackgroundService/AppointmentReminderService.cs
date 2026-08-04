using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.Infrastructure.BackgroundServices;

public class AppointmentReminderService
    : BackgroundService
{
    private readonly IServiceScopeFactory
        _scopeFactory;

    public AppointmentReminderService(
        IServiceScopeFactory scopeFactory)
    {
        _scopeFactory =
            scopeFactory;
    }

    protected override async Task ExecuteAsync(
        CancellationToken stoppingToken)
    {
        while (!stoppingToken
                   .IsCancellationRequested)
        {
            try
            {
                await ProcessRemindersAsync(
                    stoppingToken);
            }
            catch (OperationCanceledException)
                when (stoppingToken
                    .IsCancellationRequested)
            {
                break;
            }

            await Task.Delay(
                TimeSpan.FromHours(1),
                stoppingToken);
        }
    }

    private async Task ProcessRemindersAsync(
        CancellationToken cancellationToken)
    {
        using var scope =
            _scopeFactory.CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var notificationPublisher =
            scope.ServiceProvider
                .GetRequiredService<
                    INotificationPublisher>();

        var now =
            DateTime.UtcNow;

        var tomorrow =
            now.AddHours(24);

        var appointments =
            await context.Appointments
                .Include(x =>
                    x.Client)
                    .ThenInclude(x =>
                        x.User)
                .Include(x =>
                    x.Therapist)
                    .ThenInclude(x =>
                        x.User)
                .Where(x =>
                    !x.ReminderSent
                    &&
                    x.Status ==
                    AppointmentStatus.Accepted
                    &&
                    x.StartUtc <= tomorrow
                    &&
                    x.StartUtc > now)
                .ToListAsync(
                    cancellationToken);

        foreach (var appointment
                 in appointments)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            var clientEmail =
                appointment.Client
                    .User.Email;

            var therapistEmail =
                appointment.Therapist
                    .User.Email;

            if (string.IsNullOrWhiteSpace(
                    clientEmail) ||
                string.IsNullOrWhiteSpace(
                    therapistEmail))
            {
                continue;
            }

            /*
             * Klijent i terapeut pripadaju istom
             * reminder događaju, zato dijele
             * correlation ID.
             */
            var correlationId =
                Guid.NewGuid();

            var appointmentDate =
                appointment.StartUtc
                    .ToString(
                        "dd.MM.yyyy. HH:mm");

            await notificationPublisher
                .PublishEmailAsync(
                    new EmailNotificationMessage
                    {
                        CorrelationId =
                            correlationId,

                        EventType =
                            NotificationEventType
                                .AppointmentReminder,

                        RecipientEmail =
                            clientEmail,

                        RecipientName =
                            BuildFullName(
                                appointment
                                    .Client
                                    .User
                                    .FirstName,
                                appointment
                                    .Client
                                    .User
                                    .LastName),

                        Subject =
                            "Appointment Reminder",

                        TemplateName =
                            "appointment-reminder",

                        TemplateData =
                            new Dictionary<
                                string,
                                string?>
                            {
                                ["appointmentDate"] =
                                    $"{appointmentDate} UTC",

                                ["therapistName"] =
                                    BuildFullName(
                                        appointment
                                            .Therapist
                                            .User
                                            .FirstName,
                                        appointment
                                            .Therapist
                                            .User
                                            .LastName)
                            },

                        IsHtml =
                            false,

                        Source =
                            "MindBloom.API"
                    },
                    cancellationToken);

            await notificationPublisher
                .PublishEmailAsync(
                    new EmailNotificationMessage
                    {
                        CorrelationId =
                            correlationId,

                        EventType =
                            NotificationEventType
                                .AppointmentReminder,

                        RecipientEmail =
                            therapistEmail,

                        RecipientName =
                            BuildFullName(
                                appointment
                                    .Therapist
                                    .User
                                    .FirstName,
                                appointment
                                    .Therapist
                                    .User
                                    .LastName),

                        Subject =
                            "Appointment Reminder",

                        TemplateName =
                            "appointment-reminder",

                        TemplateData =
                            new Dictionary<
                                string,
                                string?>
                            {
                                ["appointmentDate"] =
                                    $"{appointmentDate} UTC",

                                ["clientName"] =
                                    BuildFullName(
                                        appointment
                                            .Client
                                            .User
                                            .FirstName,
                                        appointment
                                            .Client
                                            .User
                                            .LastName)
                            },

                        IsHtml =
                            false,

                        Source =
                            "MindBloom.API"
                    },
                    cancellationToken);

            /*
             * Reminder označavamo poslanim tek
             * kada su obje RabbitMQ poruke
             * uspješno objavljene.
             */
            appointment.ReminderSent =
                true;
        }

        await context.SaveChangesAsync(
            cancellationToken);
    }

    private static string BuildFullName(
        string? firstName,
        string? lastName)
    {
        return
            $"{firstName} {lastName}"
                .Trim();
    }
}