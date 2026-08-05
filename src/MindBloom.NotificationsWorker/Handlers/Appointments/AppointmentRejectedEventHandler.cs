using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Appointments;

public sealed class AppointmentRejectedEventHandler
    : IIntegrationEventHandler<
        AppointmentRejectedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public AppointmentRejectedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        AppointmentRejectedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var formattedDate =
            integrationEvent.StartUtc
                .ToString(
                    "dd.MM.yyyy. HH:mm");

        var reason =
            string.IsNullOrWhiteSpace(
                integrationEvent.Reason)
                ? string.Empty
                : $" Reason: "
                  + integrationEvent
                      .Reason
                      .Trim();

        var message =
            "Your appointment request for "
            + $"{formattedDate} UTC "
            + "has been rejected."
            + reason;

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Appointment rejected",
                message,
                NotificationActionType
                    .Appointment,
                appointmentId:
                    integrationEvent
                        .AppointmentId,
                resourceId:
                    integrationEvent
                        .AppointmentId,
                cancellationToken:
                    cancellationToken);
    }
}