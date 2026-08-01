using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class MembershipPlan : BaseEntity
{
    public string Name { get; set; }
        = string.Empty;

    public string Description { get; set; }
        = string.Empty;

    public MembershipPlanType PlanType { get; set; }

    public decimal Price { get; set; }

    public int DurationMonths { get; set; }

    public int IncludedSessions { get; set; }

    public decimal DiscountPercentage { get; set; }

    public string BenefitsJson { get; set; }
        = "[]";

    public bool IsActive { get; set; }

    public ICollection<MembershipPlanAudit> Audits { get; set; }
        = new List<MembershipPlanAudit>();
}