using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Privacy.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/privacy")]
[ResponseCache(
    Location = ResponseCacheLocation.None,
    NoStore = true)]
public sealed class PrivacyController
    : ControllerBase
{
    private readonly IPrivacyConsentService
        _privacyConsentService;

    public PrivacyController(
        IPrivacyConsentService
            privacyConsentService)
    {
        _privacyConsentService =
            privacyConsentService;
    }

    [AllowAnonymous]
    [HttpGet("current-versions")]
    public IActionResult GetCurrentVersions()
    {
        return Ok(
            _privacyConsentService
                .GetCurrentVersions());
    }

    [Authorize(
        Policy =
            AuthorizationPolicyConstants
                .AuthenticatedUser)]
    [HttpGet("my-consents")]
    public async Task<IActionResult>
        GetMyConsents()
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _privacyConsentService
                .GetMyConsentsAsync(
                    userId);

        return Ok(result);
    }

    private int GetAuthenticatedUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }
}