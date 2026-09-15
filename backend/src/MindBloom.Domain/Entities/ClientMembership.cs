using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class ClientMembership : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public MembershipPlanType PlanType { get; set; }

    public int TotalSessions { get; set; }

    public int RemainingSessions { get; set; }

    public decimal Price { get; set; }
    public int DurationMonths { get; set; }

    public bool IsActive { get; set; }

    public DateTime? PurchasedAtUtc { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }

    public MembershipPayment? Payment { get; set; }

    public ICollection<MembershipUsage> Usages { get; set; }
        = new List<MembershipUsage>();
}