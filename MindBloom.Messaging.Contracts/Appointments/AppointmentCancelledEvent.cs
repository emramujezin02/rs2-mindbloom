using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Appointments;

public sealed record AppointmentCancelledEvent
    : IntegrationEvent
{
    public int AppointmentId { get; init; }

    public int ClientId { get; init; }

    public int ClientUserId { get; init; }

    public int TherapistId { get; init; }

    public int TherapistUserId { get; init; }

    public int CancelledByUserId { get; init; }

    public string PreviousStatus { get; init; }
        = string.Empty;

    public string Reason { get; init; }
        = string.Empty;

    public DateTime StartUtc { get; init; }

    public DateTime EndUtc { get; init; }
}