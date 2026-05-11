using MindBloom.Domain.Entities;

public class Favorite : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;
}