using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Chat;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Chat;

public sealed class ChatMessageCreatedEventHandler
    : IIntegrationEventHandler<
        ChatMessageCreatedEvent>
{
    private readonly WorkerNotificationService
        _notificationService;

    public ChatMessageCreatedEventHandler(
        WorkerNotificationService
            notificationService)
    {
        _notificationService =
            notificationService;
    }

    public Task HandleAsync(
        ChatMessageCreatedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var senderName =
            string.IsNullOrWhiteSpace(
                integrationEvent.SenderName)
                ? "A user"
                : integrationEvent
                    .SenderName
                    .Trim();

        var preview =
            integrationEvent
                .MessagePreview
                ?.Trim()
            ?? string.Empty;

        var message =
            preview.Length == 0
                ? $"You received a new message from {senderName}."
                : $"You received a new message from {senderName}: {preview}";

        return _notificationService
            .NotifyAsync(
                integrationEvent
                    .RecipientUserId,
                "New message",
                message,
                NotificationActionType.Chat,
                appointmentId:
                    integrationEvent
                        .AppointmentId,
                resourceId:
                    integrationEvent
                        .ConversationId,
                sendEmail:
                    false,
                cancellationToken:
                    cancellationToken);
    }
}