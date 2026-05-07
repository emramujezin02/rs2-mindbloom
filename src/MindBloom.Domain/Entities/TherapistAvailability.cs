namespace MindBloom.Domain.Entities;

public class TherapistAvailability : BaseEntity
{
    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public DayOfWeek DayOfWeek { get; set; }

    public TimeSpan StartTime { get; set; }

    public TimeSpan EndTime { get; set; }
}