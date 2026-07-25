using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Common.Pagination;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Reviews.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService
        _reviewService;

    public ReviewsController(
        IReviewService reviewService)
    {
        _reviewService =
            reviewService;
    }

    [AllowAnonymous]
    [HttpGet("public")]
    public async Task<IActionResult>
    GetPublicReviews(
        [FromQuery]
        int limit = 6)
    {
        var result =
            await _reviewService
                .GetPublicReviewsAsync(
                    limit);

        return Ok(result);
    }

    [Authorize(Roles = "Client")]
    [HttpPost]
    public async Task<IActionResult>
        Create(
            CreateReviewDto request)
    {
        var userId =
            GetCurrentUserId();

        await _reviewService.CreateAsync(
            userId,
            request);

        return StatusCode(
            StatusCodes.Status201Created,
            new
            {
                message =
                    "Review added successfully."
            });
    }

    [HttpGet("therapist/{therapistId}")]
    public async Task<IActionResult>
        GetTherapistReviews(
            int therapistId,
            [FromQuery] ReviewFilterDto filter)
    {
        var result =
            await _reviewService
                .GetTherapistReviewsAsync(
                    therapistId,
                    filter);

        return Ok(result);
    }

    [HttpGet("therapist/{therapistId}/rating")]
    public async Task<IActionResult>
        GetTherapistRating(
            int therapistId)
    {
        var result =
            await _reviewService
                .GetTherapistRatingAsync(
                    therapistId);

        return Ok(result);
    }

    [Authorize(Roles = "Client")]
    [HttpGet("eligibility/{appointmentId}")]
    public async Task<IActionResult>
    GetEligibility(
        int appointmentId)
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _reviewService
                .GetEligibilityAsync(
                    userId,
                    appointmentId);

        return Ok(result);
    }

    [Authorize(Roles = "Client")]
    [HttpDelete("{reviewId}")]
    public async Task<IActionResult>
        Delete(
            int reviewId)
    {
        var userId =
            GetCurrentUserId();

        await _reviewService.DeleteAsync(
            userId,
            reviewId);

        return NoContent();
    }

    [Authorize(Roles = "Client")]
    [HttpPut("{reviewId}")]
    public async Task<IActionResult>
        Update(
            int reviewId,
            UpdateReviewDto request)
    {
        var userId =
            GetCurrentUserId();

        await _reviewService.UpdateAsync(
            userId,
            reviewId,
            request);

        return NoContent();
    }

    [Authorize(Roles = "Client")]
    [HttpGet("mine")]
    public async Task<IActionResult>
        GetMyReviews(
            [FromQuery]
            int pageNumber =
                PaginationDefaults
                    .DefaultPageNumber,
            [FromQuery]
            int pageSize =
                PaginationDefaults
                    .DefaultPageSize)
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _reviewService
                .GetMyReviewsAsync(
                    userId,
                    pageNumber,
                    pageSize);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpPut("{reviewId}/reply")]
    public async Task<IActionResult>
        ReplyToReview(
            int reviewId,
            ReplyToReviewDto request)
    {
        var userId =
            GetCurrentUserId();

        await _reviewService
            .ReplyToReviewAsync(
                userId,
                reviewId,
                request);

        return NoContent();
    }

    private int GetCurrentUserId()
    {
        var claim =
            User.FindFirst(
                ClaimTypes.NameIdentifier);

        if (claim == null ||
            !int.TryParse(
                claim.Value,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is missing or invalid.");
        }

        return userId;
    }
}