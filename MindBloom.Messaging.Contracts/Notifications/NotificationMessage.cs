namespace MindBloom.Messaging.Contracts.Notifications;

public abstract record NotificationMessage
{
    public const int CurrentVersion = 1;

    public Guid MessageId { get; init; } =
        Guid.NewGuid();

    public Guid CorrelationId { get; init; }

    public required NotificationEventType
        EventType
    { get; init; }

    public int MessageVersion { get; init; } =
        CurrentVersion;

    public DateTime CreatedAtUtc { get; init; } =
        DateTime.UtcNow;

    public int RetryCount { get; init; }

    public Guid? UserId { get; init; }

    public string? Source { get; init; }
}