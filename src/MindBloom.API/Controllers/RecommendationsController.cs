using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Application.Recommendations.Services;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/recommendations")]
[Authorize]
public sealed class RecommendationsController : ControllerBase
{
    private readonly IRecommendationService _recommendationService;

    public RecommendationsController(
        IRecommendationService recommendationService)
    {
        _recommendationService =
            recommendationService;
    }

    /// <summary>
    /// Returns a personalized and explainable therapist recommendation list
    /// for the currently authenticated client.
    /// </summary>
    /// <param name="request">
    /// Client preferences and results derived from the initial assessment.
    /// </param>
    /// <param name="cancellationToken">
    /// Request cancellation token.
    /// </param>
    /// <returns>
    /// Therapists sorted by a personalized recommendation score.
    /// </returns>
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

        var recommendations =
            await _recommendationService
                .GetRecommendationsAsync(
                    userId,
                    request,
                    cancellationToken);

        return Ok(recommendations);
    }
}