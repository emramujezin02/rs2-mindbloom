using MindBloom.Application.Features.Memberships.DTOs;

using MindBloom.Application.Common.Models;

namespace MindBloom.Application.Features.Memberships.Interfaces;

public interface IMembershipService
{
    Task<List<MembershipPlanDto>>
        GetPlansForTherapistAsync(
            int therapistId);

    Task<MembershipPaymentIntentResponseDto>
        CreatePaymentIntentAsync(
            int clientUserId,
            CreateMembershipPaymentIntentDto request);

    Task<MembershipResponseDto>
        ConfirmPaymentAsync(
            int clientUserId,
            ConfirmMembershipPaymentDto request);

    Task<PagedResponse<MembershipResponseDto>>
        GetMyMembershipsAsync(
            int clientUserId,
            int pageNumber,
            int pageSize);

    Task<MembershipReceiptDto>
        GetReceiptAsync(
            int clientUserId,
            int membershipId);

    Task UseMembershipAsync(
        int clientUserId,
        UseMembershipDto request);

    Task HandleAppointmentCancellationAsync(
        int appointmentId,
        string reason,
        bool forceRestore);

    Task FinalizeAppointmentUsageAsync(
        int appointmentId,
        string reason);
}
