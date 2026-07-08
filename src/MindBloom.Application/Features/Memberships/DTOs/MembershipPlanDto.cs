using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Memberships.DTOs;

public class MembershipPlanDto
{
    public MembershipPlanType PlanType { get; set; }

    public string Name { get; set; } = string.Empty;

    public int TotalSessions { get; set; }

    public int FreeSessions { get; set; }

    public decimal Price { get; set; }

    public decimal PricePerSession { get; set; }
}