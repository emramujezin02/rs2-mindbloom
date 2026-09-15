using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Notifications;

public abstract record NotificationMessage
    : IntegrationEvent
{
    public Guid MessageId
    {
        get => EventId;

        init => EventId = value;
    }

    public int MessageVersion
    {
        get => EventVersion;

        init => EventVersion = value;
    }

    public DateTime CreatedAtUtc
    {
        get => TimestampUtc;

        init => TimestampUtc = value;
    }

    public required NotificationEventType
        EventType
    { get; init; }

    public int RetryCount { get; init; }

    public Guid? UserId { get; init; }

    public string? Source { get; init; }
}