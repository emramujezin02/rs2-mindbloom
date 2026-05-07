namespace MindBloom.Domain.Entities;

public class Review : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public int Rating { get; set; }

    public string Comment { get; set; } = null!;
}