using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Chat;

public sealed record ChatMessageCreatedEvent
    : IntegrationEvent
{
    public int MessageId { get; init; }

    public int ConversationId { get; init; }

    public int AppointmentId { get; init; }

    public int SenderUserId { get; init; }

    public string SenderName { get; init; } =
        string.Empty;

    public int RecipientUserId { get; init; }

    public string RecipientEmail { get; init; } =
        string.Empty;

    public string RecipientName { get; init; } =
        string.Empty;

    public string MessagePreview { get; init; } =
        string.Empty;

    public DateTime SentAtUtc { get; init; }
}