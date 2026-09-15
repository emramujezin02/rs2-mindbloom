using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class MembershipUsage : BaseEntity
{
    public int ClientMembershipId { get; set; }

    public ClientMembership ClientMembership { get; set; } = null!;

    public int AppointmentId { get; set; }

    public Appointment Appointment { get; set; } = null!;

    public DateTime UsedAtUtc { get; set; }

    public MembershipUsageStatus Status { get; set; }

    public DateTime? ReservedAtUtc { get; set; }

    public DateTime? ConsumedAtUtc { get; set; }

    public DateTime? RestoredAtUtc { get; set; }

    public string? ResolutionReason { get; set; }
}