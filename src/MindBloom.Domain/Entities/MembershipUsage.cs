namespace MindBloom.Domain.Entities;

public class MembershipUsage : BaseEntity
{
    public int ClientMembershipId { get; set; }

    public ClientMembership ClientMembership { get; set; } = null!;

    public int AppointmentId { get; set; }

    public Appointment Appointment { get; set; } = null!;

    public DateTime UsedAtUtc { get; set; }
}