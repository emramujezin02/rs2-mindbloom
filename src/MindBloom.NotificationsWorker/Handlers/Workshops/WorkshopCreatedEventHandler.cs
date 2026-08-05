using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Workshops;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Workshops;

public sealed class WorkshopCreatedEventHandler
    : IIntegrationEventHandler<
        WorkshopCreatedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public WorkshopCreatedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        WorkshopCreatedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var startDate =
            integrationEvent
                .StartUtc
                .ToString(
                    "dd.MM.yyyy. HH:mm");

        var message =
            $"A new workshop \"{integrationEvent.Title}\" "
            + $"has been scheduled for {startDate} UTC.";

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .OrganizerUserId,
                "Workshop created",
                message,
                NotificationActionType
                    .Workshop,
                resourceId:
                    integrationEvent
                        .WorkshopId,
                sendEmail:
                    false,
                cancellationToken:
                    cancellationToken);
    }
}