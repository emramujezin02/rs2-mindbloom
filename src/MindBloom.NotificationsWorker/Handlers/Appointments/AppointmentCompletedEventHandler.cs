using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Appointments;

public sealed class AppointmentCompletedEventHandler
    : IIntegrationEventHandler<
        AppointmentCompletedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public AppointmentCompletedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        AppointmentCompletedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var formattedDate =
            integrationEvent.StartUtc
                .ToString(
                    "dd.MM.yyyy. HH:mm");

        var message =
            "Your appointment from "
            + $"{formattedDate} UTC "
            + "has been marked as completed.";

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Appointment completed",
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