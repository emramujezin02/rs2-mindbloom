using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Appointments;

public sealed class AppointmentCreatedEventHandler
    : IIntegrationEventHandler<
        AppointmentCreatedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public AppointmentCreatedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        AppointmentCreatedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var formattedDate =
            integrationEvent.StartUtc
                .ToString(
                    "dd.MM.yyyy. HH:mm");

        var message =
            "You have received a new "
            + "appointment request for "
            + $"{formattedDate} UTC.";

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .TherapistUserId,
                "New appointment request",
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