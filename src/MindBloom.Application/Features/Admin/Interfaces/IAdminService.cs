using MindBloom.Application.Features.Admin.DTOs;

namespace MindBloom.Application.Features.Admin.Interfaces;

public interface IAdminService
{
    Task<List<UserListDto>> GetUsersAsync();
    Task UpdateUserStatusAsync(int userId, UpdateUserStatusDto request);

    Task UpdateTherapistVerificationAsync(
    int therapistId,
    UpdateTherapistVerificationDto request);

    Task<AdminDashboardDto>
    GetDashboardAsync();
}