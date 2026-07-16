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

    [HttpGet("therapists/pending")]
    public async Task<IActionResult>
    GetPendingTherapists(
        [FromQuery]
        SearchTherapistVerificationDto request)
    {
        var result =
            await _adminService
                .GetPendingTherapistsAsync(
                    request);

        return Ok(result);
    }

    [HttpGet(
        "therapists/{therapistId}/verification")]
    public async Task<IActionResult>
        GetTherapistVerificationDetails(
            int therapistId)
    {
        var result =
            await _adminService
                .GetTherapistVerificationDetailsAsync(
                    therapistId);

        return Ok(result);
    }

    [HttpPut(
        "therapists/{therapistId}/verification")]
    public async Task<IActionResult>
        UpdateTherapistVerification(
            int therapistId,
            UpdateTherapistVerificationDto request)
    {
        var adminUserId =
            GetAuthenticatedUserId();

        await _adminService
            .UpdateTherapistVerificationAsync(
                adminUserId,
                therapistId,
                request);

        return Ok(new
        {
            message =
                request.Status ==
                MindBloom.Domain.Enums
                    .TherapistVerificationStatus
                    .Approved
                    ? "Therapist approved successfully."
                    : "Therapist rejected successfully."
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

    [HttpGet("reviews")]
    public async Task<IActionResult>
    GetReviews(
        [FromQuery]
        SearchAdminReviewsDto request)
    {
        var result =
            await _adminService
                .GetReviewsAsync(
                    request);

        return Ok(result);
    }

    [HttpGet("reviews/{reviewId}")]
    public async Task<IActionResult>
        GetReviewDetails(
            int reviewId)
    {
        var result =
            await _adminService
                .GetReviewDetailsAsync(
                    reviewId);

        return Ok(result);
    }

    [HttpPut("reviews/{reviewId}/delete")]
    public async Task<IActionResult>
        DeleteReview(
            int reviewId,
            DeleteAdminReviewDto request)
    {
        var adminUserId =
            GetAuthenticatedUserId();

        await _adminService
            .DeleteReviewAsync(
                adminUserId,
                reviewId,
                request);

        return Ok(new
        {
            message =
                "Review removed successfully."
        });
    }



   

    [HttpGet("appointments")]
    public async Task<IActionResult>
    GetAppointments(
        [FromQuery]
        SearchAdminAppointmentsDto request)
    {
        var result =
            await _adminService
                .GetAppointmentsAsync(
                    request);

        return Ok(result);
    }

    [HttpGet("appointments/{appointmentId}")]
    public async Task<IActionResult>
        GetAppointmentDetails(
            int appointmentId)
    {
        var result =
            await _adminService
                .GetAppointmentDetailsAsync(
                    appointmentId);

        return Ok(result);
    }

    [HttpPut(
        "appointments/{appointmentId}/cancel")]
    public async Task<IActionResult>
        CancelAppointment(
            int appointmentId,
            AdminCancelAppointmentDto request)
    {
        var adminUserId =
            GetAuthenticatedUserId();

        await _adminService
            .CancelAppointmentAsync(
                adminUserId,
                appointmentId,
                request);

        return Ok(new
        {
            message =
                "Appointment cancelled successfully."
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