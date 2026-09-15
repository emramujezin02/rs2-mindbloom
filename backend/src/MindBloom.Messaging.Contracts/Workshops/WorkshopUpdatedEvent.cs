using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Workshops;

public sealed record WorkshopUpdatedEvent
    : IntegrationEvent
{
    public int WorkshopId { get; init; }

    public int UpdatedByUserId { get; init; }

    public string Title { get; init; } =
        string.Empty;

    public DateTime PreviousStartUtc { get; init; }

    public DateTime PreviousEndUtc { get; init; }

    public DateTime StartUtc { get; init; }

    public DateTime EndUtc { get; init; }

    public string WorkshopType { get; init; } =
        string.Empty;

    public string? Location { get; init; }

    public string? OnlineLink { get; init; }

    public bool ScheduleChanged { get; init; }

    public bool LocationChanged { get; init; }
}