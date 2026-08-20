using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public sealed class OutboxMessage
{
    public long Id { get; set; }

    public Guid EventId { get; set; }

    public Guid CorrelationId { get; set; }

    public string EventType { get; set; } =
        string.Empty;

    public string RoutingKey { get; set; } =
        string.Empty;

    public string PayloadJson { get; set; } =
        string.Empty;

    public DateTime OccurredAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; } =
        DateTime.UtcNow;

    public DateTime? ProcessedAtUtc { get; set; }

    public string? IdempotencyKey { get; set; }

    public int AttemptCount { get; set; }

    public DateTime? LastAttemptAtUtc
    {
        get;
        set;
    }

    public DateTime? NextAttemptAtUtc
    {
        get;
        set;
    }

    public string? LastError { get; set; }

    public bool IsDeadLettered { get; set; }

    public OutboxMessageStatus Status
    {
        get;
        set;
    } = OutboxMessageStatus.Pending;
}