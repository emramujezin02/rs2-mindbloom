using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Memberships;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Memberships;

public sealed class MembershipExpiredEventHandler
    : IIntegrationEventHandler<
        MembershipExpiredEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public MembershipExpiredEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public async Task HandleAsync(
        MembershipExpiredEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var expiredDate =
            integrationEvent
                .ExpiredAtUtc
                .ToString(
                    "dd.MM.yyyy.");

        var clientMessage =
            $"Your {integrationEvent.PlanType} membership "
            + $"expired on {expiredDate}.";

        if (integrationEvent
                .RemainingSessions > 0)
        {
            clientMessage +=
                $" {integrationEvent.RemainingSessions} "
                + "unused sessions remained.";
        }

        await _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Membership expired",
                clientMessage,
                NotificationActionType
                    .Membership,
                resourceId:
                    integrationEvent
                        .MembershipId,
                cancellationToken:
                    cancellationToken);

        var therapistMessage =
            "A client membership associated "
            + "with your profile has expired.";

        await _notificationService
            .NotifyAsync(
                integrationEvent
                    .TherapistUserId,
                "Membership expired",
                therapistMessage,
                NotificationActionType
                    .Membership,
                resourceId:
                    integrationEvent
                        .MembershipId,
                sendEmail:
                    false,
                cancellationToken:
                    cancellationToken);
    }
}