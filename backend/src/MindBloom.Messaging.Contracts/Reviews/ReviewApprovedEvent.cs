using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Reviews;

public sealed record ReviewApprovedEvent
    : IntegrationEvent
{
    public int ReviewId { get; init; }

    public int AppointmentId { get; init; }

    public int ClientId { get; init; }

    public int ClientUserId { get; init; }

    public string ClientEmail { get; init; } =
        string.Empty;

    public string ClientName { get; init; } =
        string.Empty;

    public int TherapistId { get; init; }

    public int TherapistUserId { get; init; }

    public string TherapistEmail { get; init; } =
        string.Empty;

    public string TherapistName { get; init; } =
        string.Empty;

    public int Rating { get; init; }

    public DateTime ApprovedAtUtc { get; init; }

    public int ApprovedByAdminUserId { get; init; }
}