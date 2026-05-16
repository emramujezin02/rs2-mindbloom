namespace MindBloom.Domain.Entities;

public class TherapistUnavailableDate
    : BaseEntity
{
    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Reason { get; set; } = string.Empty;
}