using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    private readonly IAdminService
        _adminService;

    public AdminController(
        IAdminService adminService)
    {
        _adminService =
            adminService;
    }

    [HttpGet("users")]
    public async Task<IActionResult>
        GetUsers(
            [FromQuery]
            SearchAdminUsersDto request)
    {
        var result =
            await _adminService
                .GetUsersAsync(request);

        return Ok(result);
    }

    [HttpPut("users/{userId}/status")]
    public async Task<IActionResult>
        UpdateUserStatus(
            int userId,
            UpdateUserStatusDto request)
    {
        var authenticatedAdminUserId =
            GetAuthenticatedUserId();

        await _adminService
            .UpdateUserStatusAsync(
                authenticatedAdminUserId,
                userId,
                request);

        return Ok(new
        {
            message =
                request.IsBlocked
                    ? "User deactivated successfully."
                    : "User activated successfully."
        });
    }

    [HttpDelete("users/{userId}")]
    public IActionResult
        DeleteUser(
            int userId)
    {
        return StatusCode(
            StatusCodes
                .Status405MethodNotAllowed,
            new
            {
                message =
                    "Permanent user deletion is not allowed. "
                    + "Deactivate the user account instead."
            });
    }

    [HttpPut(
        "therapists/{therapistId}/verification")]
    public async Task<IActionResult>
        UpdateTherapistVerification(
            int therapistId,
            UpdateTherapistVerificationDto
                request)
    {
        await _adminService
            .UpdateTherapistVerificationAsync(
                therapistId,
                request);

        return Ok(new
        {
            message =
                "Therapist verification updated successfully."
        });
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult>
        GetDashboard()
    {
        var result =
            await _adminService
                .GetDashboardAsync();

        return Ok(result);
    }

    [HttpDelete("reviews/{reviewId}")]
    public async Task<IActionResult>
        DeleteReview(
            int reviewId)
    {
        await _adminService
            .DeleteReviewAsync(
                reviewId);

        return Ok(new
        {
            message =
                "Review deleted successfully."
        });
    }

    private int
        GetAuthenticatedUserId()
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
}