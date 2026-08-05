using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Appointments;

public sealed class AppointmentAcceptedEventHandler
    : IIntegrationEventHandler<
        AppointmentAcceptedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public AppointmentAcceptedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        AppointmentAcceptedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var formattedDate =
            integrationEvent.StartUtc
                .ToString(
                    "dd.MM.yyyy. HH:mm");

        var therapistName =
            string.IsNullOrWhiteSpace(
                integrationEvent.TherapistName)
                ? "your therapist"
                : integrationEvent
                    .TherapistName
                    .Trim();

        var message =
            $"Your appointment with "
            + $"{therapistName} on "
            + $"{formattedDate} UTC "
            + "has been accepted.";

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Appointment accepted",
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