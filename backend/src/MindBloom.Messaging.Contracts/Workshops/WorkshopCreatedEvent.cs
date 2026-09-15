using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Workshops;

public sealed record WorkshopCreatedEvent
    : IntegrationEvent
{
    public int WorkshopId { get; init; }

    public int OrganizerUserId { get; init; }

    public int? TherapistId { get; init; }

    public string Title { get; init; } =
        string.Empty;

    public DateTime StartUtc { get; init; }

    public DateTime EndUtc { get; init; }

    public string WorkshopType { get; init; } =
        string.Empty;

    public int Capacity { get; init; }

    public decimal Price { get; init; }
}