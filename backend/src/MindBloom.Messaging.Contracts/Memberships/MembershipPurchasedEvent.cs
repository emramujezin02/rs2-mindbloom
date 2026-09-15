using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Memberships;

public sealed record MembershipPurchasedEvent
    : IntegrationEvent
{
    public int MembershipId { get; init; }

    public int ClientId { get; init; }

    public int ClientUserId { get; init; }

    public int TherapistId { get; init; }

    public int TherapistUserId { get; init; }

    public string PlanType { get; init; } =
        string.Empty;

    public int TotalSessions { get; init; }

    public decimal Price { get; init; }

    public string Currency { get; init; } =
        string.Empty;

    public DateTime PurchasedAtUtc { get; init; }

    public DateTime? ExpiresAtUtc { get; init; }
}