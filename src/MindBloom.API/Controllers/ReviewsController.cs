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

    [HttpPost]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult> Create(
        CreateReviewDto request)
    {
        var userId =
            int.Parse(
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier)!);

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
        GetTherapistReviews(int therapistId)
    {
        var result =
            await _reviewService
                .GetTherapistReviewsAsync(
                    therapistId);

        return Ok(result);
    }
}