using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Appointments;

public sealed record AppointmentRejectedEvent
    : IntegrationEvent
{
    public int AppointmentId { get; init; }

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

    public DateTime StartUtc { get; init; }

    public DateTime EndUtc { get; init; }

    public string Reason { get; init; } =
        string.Empty;
}