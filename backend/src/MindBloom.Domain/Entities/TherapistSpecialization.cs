namespace MindBloom.Domain.Entities;

public class TherapistSpecialization : BaseEntity
{
    public ICollection<ClientSpecialization> ClientSpecializations { get; set; } = new List<ClientSpecialization>();

    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<Therapist> Therapists { get; set; } =
        new List<Therapist>();
}