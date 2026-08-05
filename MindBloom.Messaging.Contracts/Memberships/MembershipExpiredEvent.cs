using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Memberships;

public sealed record MembershipExpiredEvent
    : IntegrationEvent
{
    public int MembershipId { get; init; }

    public int ClientId { get; init; }

    public int ClientUserId { get; init; }

    public string ClientEmail { get; init; } =
        string.Empty;

    public string ClientName { get; init; } =
        string.Empty;

    public int TherapistId { get; init; }

    public int TherapistUserId { get; init; }

    public string TherapistName { get; init; } =
        string.Empty;

    public string PlanType { get; init; } =
        string.Empty;

    public DateTime ExpiredAtUtc { get; init; }

    public int RemainingSessions { get; init; }
}