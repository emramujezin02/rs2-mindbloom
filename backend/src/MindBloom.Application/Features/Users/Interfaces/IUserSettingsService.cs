using MindBloom.Application.Features.Users.DTOs;

namespace MindBloom.Application.Features.Users.Interfaces;

public interface IUserSettingsService
{
    Task<UserSettingsDto> GetAsync(
        int userId);

    Task<UserSettingsDto> UpdateAsync(
        int userId,
        UpdateUserSettingsDto request);
}