using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Appointments;

public sealed record AppointmentCompletedEvent
    : IntegrationEvent
{
    public int AppointmentId { get; init; }

    public int ClientId { get; init; }

    public int ClientUserId { get; init; }

    public int TherapistId { get; init; }

    public int TherapistUserId { get; init; }

    public int? CompletedByUserId { get; init; }

    public DateTime StartUtc { get; init; }

    public DateTime EndUtc { get; init; }

    public string AppointmentType { get; init; }
        = string.Empty;

    public decimal Price { get; init; }

    public bool IsPaid { get; init; }
}