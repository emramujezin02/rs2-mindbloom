using MindBloom.Application.Features.Memberships.DTOs;

namespace MindBloom.Application.Features.Memberships.Interfaces;

public interface IMembershipService
{
    Task<List<MembershipPlanDto>> GetPlansForTherapistAsync(
        int therapistId);

    Task<MembershipResponseDto> PurchaseAsync(
        int clientUserId,
        PurchaseMembershipDto request);

    Task<List<MembershipResponseDto>> GetMyMembershipsAsync(
        int clientUserId);

    Task UseMembershipAsync(
        int clientUserId,
        UseMembershipDto request);
}