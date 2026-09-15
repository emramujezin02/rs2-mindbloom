namespace MindBloom.Domain.Entities;

public class AppointmentNote : BaseEntity
{
    public int AppointmentId { get; set; }

    public Appointment Appointment { get; set; } = null!;

    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public string Notes { get; set; } = string.Empty;

    public string ClientMood { get; set; } = string.Empty;

    public string Recommendations { get; set; } = string.Empty;

    public bool FollowUpNeeded { get; set; }
}