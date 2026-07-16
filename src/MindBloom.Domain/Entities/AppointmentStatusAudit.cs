using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class AppointmentStatusAudit
    : BaseEntity
{
    public int AppointmentId { get; set; }

    public Appointment Appointment { get; set; }
        = null!;

    public int ChangedByUserId { get; set; }

    public ApplicationUser ChangedByUser { get; set; }
        = null!;

    public AppointmentStatus? PreviousStatus { get; set; }

    public AppointmentStatus NewStatus { get; set; }

    public string Action { get; set; }
        = string.Empty;

    public string? Reason { get; set; }

    public DateTime ChangedAtUtc { get; set; }
}