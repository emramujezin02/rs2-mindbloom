namespace MindBloom.Domain.Entities;

public class TherapyApproach : BaseEntity
{
    public string Name { get; set; } = string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;

    public ICollection<TherapistTherapyApproach> TherapistTherapyApproaches
    { get; set; } = new List<TherapistTherapyApproach>();

    public ICollection<ClientTherapyApproach>
    ClientTherapyApproaches
    {
        get;
        set;
    } = new List<ClientTherapyApproach>();
}