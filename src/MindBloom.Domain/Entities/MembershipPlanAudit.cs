namespace MindBloom.Domain.Entities;

public class MembershipPlanAudit : BaseEntity
{
    public int MembershipPlanId { get; set; }

    public MembershipPlan MembershipPlan { get; set; }
        = null!;

    public int ChangedByUserId { get; set; }

    public ApplicationUser ChangedByUser { get; set; }
        = null!;

    public string Action { get; set; }
        = string.Empty;

    public string? PreviousValues { get; set; }

    public string? NewValues { get; set; }

    public string? Reason { get; set; }

    public DateTime ChangedAtUtc { get; set; }
}