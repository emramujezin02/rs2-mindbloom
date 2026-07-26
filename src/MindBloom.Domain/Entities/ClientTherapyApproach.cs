namespace MindBloom.Domain.Entities;

public sealed class ClientTherapyApproach
    : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; }
        = null!;

    public int TherapyApproachId { get; set; }

    public TherapyApproach TherapyApproach
    {
        get;
        set;
    } = null!;
}