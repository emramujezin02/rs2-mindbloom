using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Reviews;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Reviews;

public sealed class ReviewApprovedEventHandler
    : IIntegrationEventHandler<
        ReviewApprovedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public ReviewApprovedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public async Task HandleAsync(
        ReviewApprovedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var clientMessage =
            "Your review has been approved "
            + "and is now publicly visible.";

        await _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Review approved",
                clientMessage,
                NotificationActionType
                    .Review,
                resourceId:
                    integrationEvent
                        .ReviewId,
                sendEmail:
                    false,
                cancellationToken:
                    cancellationToken);

        var therapistMessage =
            $"A new approved review with "
            + $"{integrationEvent.Rating}/5 rating "
            + "has been published on your profile.";

        await _notificationService
            .NotifyAsync(
                integrationEvent
                    .TherapistUserId,
                "New approved review",
                therapistMessage,
                NotificationActionType
                    .Review,
                resourceId:
                    integrationEvent
                        .ReviewId,
                sendEmail:
                    false,
                cancellationToken:
                    cancellationToken);
    }
}