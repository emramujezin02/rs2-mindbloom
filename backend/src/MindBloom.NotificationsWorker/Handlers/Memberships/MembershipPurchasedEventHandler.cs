using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Memberships;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Memberships;

public sealed class MembershipPurchasedEventHandler
    : IIntegrationEventHandler<
        MembershipPurchasedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public MembershipPurchasedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public async Task HandleAsync(
        MembershipPurchasedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var expirationText =
            integrationEvent.ExpiresAtUtc.HasValue
                ? $" It is valid until "
                  + integrationEvent
                      .ExpiresAtUtc
                      .Value
                      .ToString(
                          "dd.MM.yyyy.")
                  + "."
                : string.Empty;

        var clientMessage =
            $"Your {integrationEvent.PlanType} membership "
            + $"has been activated with "
            + $"{integrationEvent.TotalSessions} sessions."
            + expirationText;

        await _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Membership activated",
                clientMessage,
                NotificationActionType
                    .Membership,
                resourceId:
                    integrationEvent
                        .MembershipId,
                cancellationToken:
                    cancellationToken);

        var therapistMessage =
            "A client purchased a membership "
            + $"with {integrationEvent.TotalSessions} "
            + "sessions with you.";

        await _notificationService
            .NotifyAsync(
                integrationEvent
                    .TherapistUserId,
                "New membership",
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