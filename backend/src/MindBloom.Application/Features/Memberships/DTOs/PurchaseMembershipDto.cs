using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Memberships.DTOs;

public class PurchaseMembershipDto
{
    public int TherapistId { get; set; }

    public MembershipPlanType PlanType { get; set; }
}