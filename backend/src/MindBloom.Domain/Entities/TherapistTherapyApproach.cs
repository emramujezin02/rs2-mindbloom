namespace MindBloom.Domain.Entities;

public class TherapistTherapyApproach : BaseEntity
{
    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public int TherapyApproachId { get; set; }

    public TherapyApproach TherapyApproach { get; set; } = null!;
}