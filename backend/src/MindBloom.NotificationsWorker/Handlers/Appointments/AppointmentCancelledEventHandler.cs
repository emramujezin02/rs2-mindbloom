using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Appointments;

public sealed class AppointmentCancelledEventHandler
    : IIntegrationEventHandler<
        AppointmentCancelledEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public AppointmentCancelledEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public async Task HandleAsync(
        AppointmentCancelledEvent integrationEvent,
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
            "The appointment scheduled for "
            + $"{formattedDate} UTC "
            + "has been cancelled."
            + reason;

        var cancelledByClient =
            integrationEvent
                .CancelledByUserId ==
            integrationEvent
                .ClientUserId;

        var cancelledByTherapist =
            integrationEvent
                .CancelledByUserId ==
            integrationEvent
                .TherapistUserId;

        if (cancelledByClient)
        {
            await NotifyAsync(
                integrationEvent
                    .TherapistUserId,
                integrationEvent,
                message,
                cancellationToken);

            return;
        }

        if (cancelledByTherapist)
        {
            await NotifyAsync(
                integrationEvent
                    .ClientUserId,
                integrationEvent,
                message,
                cancellationToken);

            return;
        }

        /*
         * Ako akciju nije izvršio ni klijent
         * ni terapeut, pretpostavljamo
         * administrativno/sistemsko
         * otkazivanje i obavještavamo obje
         * strane.
         */
        await NotifyAsync(
            integrationEvent
                .ClientUserId,
            integrationEvent,
            message,
            cancellationToken);

        await NotifyAsync(
            integrationEvent
                .TherapistUserId,
            integrationEvent,
            message,
            cancellationToken);
    }

    private Task NotifyAsync(
        int userId,
        AppointmentCancelledEvent
            integrationEvent,
        string message,
        CancellationToken cancellationToken)
    {
        return _notificationService
            .NotifyAsync(
                userId,
                "Appointment cancelled",
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