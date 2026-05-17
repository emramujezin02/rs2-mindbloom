using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Reviews.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReviewsController : ControllerBase
{
    private readonly IReviewService _reviewService;

    public ReviewsController(
        IReviewService reviewService)
    {
        _reviewService = reviewService;
    }

    [Authorize(Roles = "Client")]
    [HttpPost]
    public async Task<IActionResult>
        Create(
            CreateReviewDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                    .Value);

        await _reviewService.CreateAsync(
            userId,
            request);

        return Ok(new
        {
            message = "Review added successfully."
        });
    }

    [HttpGet("therapist/{therapistId}")]
    public async Task<IActionResult>
        GetTherapistReviews(
            int therapistId)
    {
        var result =
            await _reviewService
                .GetTherapistReviewsAsync(
                    therapistId);

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
    [HttpDelete("{reviewId}")]
    public async Task<IActionResult>
    Delete(int reviewId)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                        .Value);

        await _reviewService.DeleteAsync(
            userId,
            reviewId);

        return Ok(
            "Review deleted successfully.");
    }

    [HttpPut("{reviewId}")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult> Update(
    int reviewId,
    UpdateReviewDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _reviewService.UpdateAsync(
            userId,
            reviewId,
            request);

        return Ok(
            new
            {
                message =
                    "Review updated successfully."
            });
    }

    [Authorize(Roles = "Client")]
    [HttpGet("mine")]
    public async Task<IActionResult>
    GetMyReviews()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        var result =
            await _reviewService
                .GetMyReviewsAsync(
                    userId);

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
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _reviewService
            .ReplyToReviewAsync(
                userId,
                reviewId,
                request);

        return Ok(new
        {
            message =
                "Reply added successfully."
        });
    }
}