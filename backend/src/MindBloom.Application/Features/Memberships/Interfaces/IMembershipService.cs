using MindBloom.Application.Features.Memberships.DTOs;

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

    Task<List<MembershipResponseDto>>
        GetMyMembershipsAsync(
            int clientUserId);

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