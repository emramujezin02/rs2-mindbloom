namespace MindBloom.Domain.Entities;

public class TherapistLocation : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string Country { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
    public ICollection<Therapist> Therapists { get; set; } = new List<Therapist>();
}
