using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Application.Recommendations.Services;
using MindBloom.Shared.Constants;
using Microsoft.Extensions.Logging;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/recommendations")]
[Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
public sealed class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _recommendationService;
    private readonly ILogger<
    RecommendationsController>
    _logger;
    public RecommendationsController(
        IRecommendationService recommendationService,
        ILogger<RecommendationsController> logger)
    {
        _recommendationService =
            recommendationService;

        _logger =
            logger;
    }

    [EnableRateLimiting(
    RateLimitPolicyConstants
        .Recommendations)]
    [HttpPost("therapists")]
    [ProducesResponseType(
        typeof(IReadOnlyList<TherapistRecommendationDto>),
        StatusCodes.Status200OK)]
    [ProducesResponseType(
        StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(
        StatusCodes.Status404NotFound)]
    public async Task<ActionResult<
        IReadOnlyList<TherapistRecommendationDto>>>
        GetTherapistRecommendations(
            [FromBody]
            TherapistRecommendationRequestDto request,
            CancellationToken cancellationToken)
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            return Unauthorized(
                new
                {
                    message =
                        "Authenticated user identifier is missing or invalid."
                });
        }

        try
        {
            var recommendations =
                await _recommendationService
                    .GetRecommendationsAsync(
                        userId,
                        request,
                        cancellationToken);

            return Ok(recommendations);
        }
        catch (OperationCanceledException)
            when (cancellationToken
                .IsCancellationRequested)
        {
            throw;
        }
        catch (KeyNotFoundException)
        {
            throw;
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Therapist recommendation calculation failed. "
                + "A safe empty fallback was returned. "
                + "Module: {Module}, UserId: {UserId}.",
                "Recommendations",
                userId);

            return Ok(
                Array.Empty<
                    TherapistRecommendationDto>());
        }
    }
}