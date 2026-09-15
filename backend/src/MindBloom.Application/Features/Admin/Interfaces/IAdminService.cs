using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Admin.DTOs;

namespace MindBloom.Application.Features.Admin.Interfaces;

public interface IAdminService
{
    Task<PagedResponse<UserListDto>>
        GetUsersAsync(
            SearchAdminUsersDto request);

    Task UpdateUserStatusAsync(
        int authenticatedAdminUserId,
        int userId,
        UpdateUserStatusDto request);

    Task UnlockUserAsync(
    int authenticatedAdminUserId,
    int userId);

    Task<PagedResponse<TherapistVerificationListDto>>
        GetPendingTherapistsAsync(
            SearchTherapistVerificationDto request);

    Task<TherapistVerificationDetailsDto>
        GetTherapistVerificationDetailsAsync(
            int therapistId);

    Task UpdateTherapistVerificationAsync(
        int authenticatedAdminUserId,
        int therapistId,
        UpdateTherapistVerificationDto request);

    Task<PagedResponse<AdminReviewListDto>>
        GetReviewsAsync(
            SearchAdminReviewsDto request);

    Task<AdminReviewDetailsDto> GetReviewDetailsAsync(int reviewId);
    Task ApproveReviewAsync(int authenticatedAdminUserId, int reviewId);

    Task DeleteReviewAsync(
        int authenticatedAdminUserId,
        int reviewId,
        DeleteAdminReviewDto request);

    Task<PagedResponse<AdminAppointmentListDto>>
        GetAppointmentsAsync(
            SearchAdminAppointmentsDto request);

    Task<AdminAppointmentDetailsDto>
        GetAppointmentDetailsAsync(
            int appointmentId);

    Task CancelAppointmentAsync(
        int authenticatedAdminUserId,
        int appointmentId,
        AdminCancelAppointmentDto request);

    Task<PagedResponse<AdminPaymentListDto>>
        GetPaymentsAsync(
            SearchAdminPaymentsDto request);

    Task<AdminPaymentDetailsDto>
        GetPaymentDetailsAsync(
            string paymentType,
            int paymentId);

    Task<AdminPaymentReceiptDto>
        GetPaymentReceiptAsync(
            string paymentType,
            int paymentId);

    Task RefundPaymentAsync(
        int authenticatedAdminUserId,
        string paymentType,
        int paymentId,
        AdminRefundPaymentDto request);

    Task<PagedResponse<AdminMembershipListDto>>
    GetMembershipsAsync(
        SearchAdminMembershipsDto request);

    Task<AdminMembershipDetailsDto>
        GetMembershipDetailsAsync(
            int membershipId);

    Task<AdminDashboardDto>
        GetDashboardAsync();

    Task<AdminUserDetailsDto>
    GetUserDetailsAsync(
        int userId);

    Task SendPasswordResetAsync(
        int authenticatedAdminUserId,
        int userId);

    Task UpdateUserAsync(
        int authenticatedAdminUserId,
        int userId,
        UpdateAdminUserDto request);

    Task<List<AdminMembershipPlanDto>>
    GetMembershipPlansAsync();

    Task<AdminMembershipPlanDto>
        GetMembershipPlanAsync(
            int planId);

    Task<int>
        CreateMembershipPlanAsync(
            int authenticatedAdminUserId,
            CreateMembershipPlanDto request);

    Task UpdateMembershipPlanAsync(
        int authenticatedAdminUserId,
        int planId,
        UpdateMembershipPlanDto request);

    Task UpdateMembershipPlanStatusAsync(
        int authenticatedAdminUserId,
        int planId,
        UpdateMembershipPlanStatusDto request);

    Task DeleteMembershipPlanAsync(
        int authenticatedAdminUserId,
        int planId);

    Task<List<AdminMembershipPlanAuditDto>>
        GetMembershipPlanHistoryAsync(
            int planId);

    Task RejectReviewAsync(
    int authenticatedAdminUserId,
    int reviewId,
    RejectAdminReviewDto request);

    Task HideReviewAsync(
        int authenticatedAdminUserId,
        int reviewId,
        HideAdminReviewDto request);
}