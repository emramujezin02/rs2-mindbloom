using Microsoft.AspNetCore.Http;
using MindBloom.Application.Features.Users.DTOs;

namespace MindBloom.Application.Features.Users.Interfaces;

public interface IUserProfileService
{
    Task<UserProfileDto> GetCurrentUserProfileAsync(
        int userId);

    Task<UserProfileDto> UpdateCurrentUserProfileAsync(
        int userId,
        UpdateUserProfileDto request);

    Task<UserProfileDto> UploadProfileImageAsync(
        int userId,
        IFormFile file);
}