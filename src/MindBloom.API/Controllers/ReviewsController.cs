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
}