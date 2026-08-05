using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application
    .Features.ClientOnboarding.DTOs;
using MindBloom.Application
    .Features.ClientOnboarding.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/client-onboarding")]
[Authorize(Policy = "ClientOnly")]
public sealed class ClientOnboardingController
    : ControllerBase
{
    private readonly IClientOnboardingService
        _onboardingService;

    public ClientOnboardingController(
        IClientOnboardingService
            onboardingService)
    {
        _onboardingService =
            onboardingService;
    }

    [HttpGet]
    public async Task<IActionResult>
        GetMyOnboarding()
    {
        var result =
            await _onboardingService
                .GetAsync(
                    GetCurrentUserId());

        return Ok(result);
    }

    [HttpPut]
    public async Task<IActionResult>
        SaveMyOnboarding(
            [FromBody]
            SaveClientOnboardingDto request)
    {
        var result =
            await _onboardingService
                .SaveAsync(
                    GetCurrentUserId(),
                    request);

        return Ok(result);
    }

    private int GetCurrentUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId))
        {
            throw new UnauthorizedException(
                "Authenticated user identifier is invalid.");
        }

        return userId;
    }
}