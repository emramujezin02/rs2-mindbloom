using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Payments;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Payments;

public sealed class PaymentSucceededEventHandler
    : IIntegrationEventHandler<
        PaymentSucceededEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public PaymentSucceededEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        PaymentSucceededEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var message =
            $"Your payment of "
            + $"{integrationEvent.Amount:F2} "
            + $"{integrationEvent.Currency.ToUpperInvariant()} "
            + "was completed successfully.";

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .ClientUserId,
                "Payment completed",
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
                sendEmail:
                    false,
                cancellationToken:
                    cancellationToken);
    }
}