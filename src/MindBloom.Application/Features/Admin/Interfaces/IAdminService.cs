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

    Task<AdminDashboardDto>
        GetDashboardAsync();

    Task DeleteReviewAsync(
        int reviewId);
}