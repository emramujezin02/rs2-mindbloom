namespace MindBloom.Domain.Entities;

public sealed class ProcessedMessage
    : BaseEntity
{
    public Guid MessageId { get; set; }

    public string ConsumerName { get; set; } =
        string.Empty;

    public string MessageType { get; set; } =
        string.Empty;

    public Guid? CorrelationId { get; set; }

    public DateTime ProcessedAtUtc { get; set; }
}