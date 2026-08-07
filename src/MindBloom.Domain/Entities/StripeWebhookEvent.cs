namespace MindBloom.Domain.Entities;

public sealed class StripeWebhookEvent
    : BaseEntity
{
    public string StripeEventId { get; set; } =
        string.Empty;

    public string EventType { get; set; } =
        string.Empty;

    public string? StripePaymentIntentId
    {
        get;
        set;
    }

    public DateTime ReceivedAtUtc { get; set; }

    public DateTime? ProcessedAtUtc { get; set; }

    public bool IsProcessed { get; set; }

    public string? FailureReason { get; set; }
}