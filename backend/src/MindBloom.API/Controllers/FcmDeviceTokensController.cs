using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/fcm-tokens")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public sealed class FcmDeviceTokensController
    : ControllerBase
{
    private readonly IFcmDeviceTokenService
        _fcmDeviceTokenService;

    public FcmDeviceTokensController(
        IFcmDeviceTokenService
            fcmDeviceTokenService)
    {
        _fcmDeviceTokenService =
            fcmDeviceTokenService;
    }

    [HttpPost]
    public async Task<IActionResult> Register(
        [FromBody]
        RegisterFcmTokenDto request,
        CancellationToken cancellationToken)
    {
        var userId =
            GetCurrentUserId();

        await _fcmDeviceTokenService
            .RegisterAsync(
                userId,
                request,
                cancellationToken);

        return NoContent();
    }

    [HttpDelete]
    public async Task<IActionResult> Unregister(
        [FromBody]
        UnregisterFcmTokenDto request,
        CancellationToken cancellationToken)
    {
        var userId =
            GetCurrentUserId();

        await _fcmDeviceTokenService
            .UnregisterAsync(
                userId,
                request,
                cancellationToken);

        return NoContent();
    }

    private int GetCurrentUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId) ||
            userId <= 0)
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is missing or invalid.");
        }

        return userId;
    }
}