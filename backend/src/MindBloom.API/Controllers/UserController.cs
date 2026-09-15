using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.Application.Features.Users.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public class UsersController : ControllerBase
{
    private readonly IUserProfileService
        _userProfileService;

    public UsersController(
        IUserProfileService userProfileService)
    {
        _userProfileService =
            userProfileService;
    }

    [HttpGet("me")]
    public async Task<IActionResult>
        GetMyProfile()
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _userProfileService
                .GetCurrentUserProfileAsync(
                    userId);

        return Ok(result);
    }

    [HttpPut("me")]
    public async Task<IActionResult>
        UpdateMyProfile(
            UpdateUserProfileDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _userProfileService
                .UpdateCurrentUserProfileAsync(
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

    [EnableRateLimiting(
    RateLimitPolicyConstants.Uploads)]
    [HttpPost("me/profile-image")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<IActionResult>
    UploadMyProfileImage(
        [FromForm]
        UploadProfileImageDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _userProfileService
                .UploadProfileImageAsync(
                    userId,
                    request.File);

        return Ok(result);
    }
}