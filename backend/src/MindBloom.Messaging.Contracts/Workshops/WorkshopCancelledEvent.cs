using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Workshops;

public sealed record WorkshopCancelledEvent
    : IntegrationEvent
{
    public int WorkshopId { get; init; }

    public int CancelledByUserId { get; init; }

    public string Title { get; init; } =
        string.Empty;

    public string Reason { get; init; } =
        string.Empty;

    public DateTime StartUtc { get; init; }

    public DateTime EndUtc { get; init; }
}