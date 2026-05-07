using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class Appointment : BaseEntity
{
    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public DateTime StartTimeUtc { get; set; }

    public DateTime EndTimeUtc { get; set; }

    public AppointmentStatus Status { get; set; }

    public bool IsOnline { get; set; }

    public string? OnlineMeetingUrl { get; set; }

    public string? CancellationReason { get; set; }

    public bool IsPaid { get; set; }

    public decimal PaidAmount { get; set; }
}