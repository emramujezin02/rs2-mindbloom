namespace MindBloom.Messaging.Contracts.Common;

public abstract record IntegrationEvent
{
    public const int CurrentVersion = 1;

    public Guid EventId { get; init; } =
        Guid.NewGuid();

    public Guid CorrelationId { get; init; } =
        Guid.NewGuid();

    public DateTime TimestampUtc { get; init; } =
        DateTime.UtcNow;

    public int EventVersion { get; init; } =
        CurrentVersion;
}