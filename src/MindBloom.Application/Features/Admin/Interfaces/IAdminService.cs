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

    Task<AdminReviewDetailsDto>
        GetReviewDetailsAsync(
            int reviewId);

    Task DeleteReviewAsync(
        int authenticatedAdminUserId,
        int reviewId,
        DeleteAdminReviewDto request);

    Task<AdminDashboardDto>
        GetDashboardAsync();
}