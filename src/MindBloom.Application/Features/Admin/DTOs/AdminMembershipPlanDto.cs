using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminMembershipPlanDto
{
    public int Id { get; set; }

    public MembershipPlanType PlanType { get; set; }

    public string Name { get; set; }
        = string.Empty;

    public string Description { get; set; }
        = string.Empty;

    public decimal Price { get; set; }

    public int DurationMonths { get; set; }

    public int IncludedSessions { get; set; }

    public decimal DiscountPercentage { get; set; }

    public List<string> Benefits { get; set; }
        = [];

    public bool IsActive { get; set; }

    public bool IsDeleted { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }
}