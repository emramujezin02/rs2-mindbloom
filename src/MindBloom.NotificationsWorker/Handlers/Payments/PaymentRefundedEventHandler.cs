using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Payments;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Payments;

public sealed class PaymentRefundedEventHandler
    : IIntegrationEventHandler<
        PaymentRefundedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public PaymentRefundedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        PaymentRefundedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var reason =
            string.IsNullOrWhiteSpace(
                integrationEvent.Reason)
                ? string.Empty
                : $" Reason: "
                  + integrationEvent
                      .Reason
                      .Trim();

        var message =
            $"Your payment of "
            + $"{integrationEvent.Amount:F2} "
            + $"{integrationEvent.Currency.ToUpperInvariant()} "
            + "has been refunded."
            + reason;

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Payment refunded",
                message,
                NotificationActionType.Payment,
                appointmentId:
                    integrationEvent
                        .AppointmentId,
                resourceId:
                    integrationEvent
                        .MembershipId
                    ?? integrationEvent
                        .AppointmentId,
                cancellationToken:
                    cancellationToken);
    }
}