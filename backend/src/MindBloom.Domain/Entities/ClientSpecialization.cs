namespace MindBloom.Domain.Entities;

public sealed class ClientSpecialization : BaseEntity
{
    public int ClientId { get; set; }
    public Client Client { get; set; } = null!;
    public int TherapistSpecializationId { get; set; }
    public TherapistSpecialization TherapistSpecialization { get; set; } = null!;
}
