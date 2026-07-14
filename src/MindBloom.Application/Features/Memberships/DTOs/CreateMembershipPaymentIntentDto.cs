using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Memberships.DTOs;

public class CreateMembershipPaymentIntentDto
{
    public int TherapistId { get; set; }

    public MembershipPlanType PlanType { get; set; }
}