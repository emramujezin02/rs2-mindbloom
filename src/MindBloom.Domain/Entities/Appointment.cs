using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class Appointment : BaseEntity
{
    public int ClientId { get; set; }

    public ApplicationUser Client { get; set; } = null!;

    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public DateTime AppointmentDateUtc { get; set; }

    public AppointmentStatus Status { get; set; }

    public string? Notes { get; set; }

    public decimal Price { get; set; }

    public bool IsPaid { get; set; }

    public Payment? Payment { get; set; }

    public ICollection<Notification> Notifications { get; set; }
        = new List<Notification>();
}