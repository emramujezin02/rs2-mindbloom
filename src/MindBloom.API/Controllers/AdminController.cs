using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Common.Exceptions;
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
                request.Status switch
                {
                    MindBloom.Domain.Enums
                        .TherapistVerificationStatus
                        .Approved =>
                        "Therapist approved successfully.",

                    MindBloom.Domain.Enums
                        .TherapistVerificationStatus
                        .Rejected =>
                        "Therapist rejected successfully.",

                    MindBloom.Domain.Enums
                        .TherapistVerificationStatus
                        .RequiresChanges =>
                        "Therapist application returned for changes.",

                    _ =>
                        "Therapist verification updated."
                }
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

    [HttpPut("reviews/{reviewId}/approve")]
    public async Task<IActionResult>
    ApproveReview(
        int reviewId)
    {
        var adminUserId =
            GetAuthenticatedUserId();

        await _adminService
            .ApproveReviewAsync(
                adminUserId,
                reviewId);

        return Ok(new
        {
            message =
                "Review approved successfully."
        });
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
    [HttpGet("payments")]
    public async Task<IActionResult>
    GetPayments(
        [FromQuery]
        SearchAdminPaymentsDto request)
    {
        var result =
            await _adminService
                .GetPaymentsAsync(
                    request);

        return Ok(result);
    }

    [HttpGet(
     "payments/{paymentType}/{paymentId:int}")]
    public async Task<IActionResult>
     GetPaymentDetails(
         string paymentType,
         int paymentId)
    {
        var result =
            await _adminService
                .GetPaymentDetailsAsync(
                    paymentType,
                    paymentId);

        return Ok(result);
    }

    [HttpGet(
        "payments/{paymentType}/{paymentId:int}/receipt")]
    public async Task<IActionResult>
        GetPaymentReceipt(
           string paymentType,
int paymentId)
    {
        var result =
            await _adminService
                .GetPaymentReceiptAsync(
                    paymentType,
                    paymentId);

        return Ok(result);
    }

    [HttpPut(
        "payments/{paymentType}/{paymentId:int}/refund")]
    public async Task<IActionResult>
        RefundPayment(
string paymentType,
int paymentId,
AdminRefundPaymentDto request)
    {
        var adminUserId =
            GetAuthenticatedUserId();

        await _adminService
            .RefundPaymentAsync(
                adminUserId,
                paymentType,
                paymentId,
                request);

        return Ok(new
        {
            message =
                "Refund request processed successfully."
        });
    }

    [HttpGet("memberships")]
    public async Task<IActionResult>
    GetMemberships(
        [FromQuery]
        SearchAdminMembershipsDto request)
    {
        var result =
            await _adminService
                .GetMembershipsAsync(
                    request);

        return Ok(result);
    }

    [HttpGet(
        "memberships/{membershipId}")]
    public async Task<IActionResult>
        GetMembershipDetails(
            int membershipId)
    {
        var result =
            await _adminService
                .GetMembershipDetailsAsync(
                    membershipId);

        return Ok(result);
    }

    private int GetAuthenticatedUserId()
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Invalid authenticated administrator.");
        }

        return userId;
    }

    [HttpGet("users/{userId}")]
    public async Task<IActionResult>
    GetUserDetails(
        int userId)
    {
        var result =
            await _adminService
                .GetUserDetailsAsync(
                    userId);

        return Ok(result);
    }

    [HttpPost("users/{userId:int}/send-password-reset")]
    public async Task<IActionResult> SendPasswordReset(
        int userId)
    {
        var authenticatedAdminUserId =
            GetAuthenticatedUserId();

        await _adminService.SendPasswordResetAsync(
            authenticatedAdminUserId,
            userId);

        return Ok(new
        {
            message =
                "Password reset email sent successfully."
        });
    }

    [HttpPut("users/{userId:int}")]
    public async Task<IActionResult> UpdateUser(
        int userId,
        UpdateAdminUserDto request)
    {
        var authenticatedAdminUserId =
            GetAuthenticatedUserId();

        await _adminService.UpdateUserAsync(
            authenticatedAdminUserId,
            userId,
            request);

        return Ok(new
        {
            message = "User updated successfully."
        });
    }
}