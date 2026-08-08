using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.Application.Features.Users.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/user-settings")]
[ResponseCache(
    Location = ResponseCacheLocation.None,
    NoStore = true)]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public class UserSettingsController : ControllerBase
{
    private readonly IUserSettingsService
        _userSettingsService;

    public UserSettingsController(
        IUserSettingsService userSettingsService)
    {
        _userSettingsService =
            userSettingsService;
    }

    [HttpGet("me")]
    public async Task<IActionResult> GetMySettings()
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _userSettingsService
                .GetAsync(userId);

        return Ok(result);
    }

    [HttpPut("me")]
    public async Task<IActionResult> UpdateMySettings(
        UpdateUserSettingsDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _userSettingsService
                .UpdateAsync(
                    userId,
                    request);

        return Ok(result);
    }

    private int GetAuthenticatedUserId()
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }
}