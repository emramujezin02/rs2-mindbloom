using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class Appointment : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public DateTime AppointmentDateUtc { get; set; }

    public AppointmentStatus Status { get; set; }

    public string? Notes { get; set; }

    public Conversation? Conversation { get; set; }

    public decimal Price { get; set; }

    public bool IsPaid { get; set; }

    public Payment? Payment { get; set; }

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public AppointmentType Type { get; set; }

    public string? MeetingLink { get; set; }

    public string? Location { get; set; }

    public bool ReminderSent { get; set; }

    public AppointmentNote? AppointmentNote { get; set; }

    public ICollection<Notification> Notifications { get; set; } = new List<Notification>();
    public ICollection<AppointmentStatusAudit> StatusAudits { get; set; } = new List<AppointmentStatusAudit>();
}