using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/admin")]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    private readonly IAdminService
        _adminService;

    public AdminController(
        IAdminService adminService)
    {
        _adminService = adminService;
    }

    [HttpGet("users")]
    public async Task<IActionResult>
        GetUsers()
    {
        var result =
            await _adminService
                .GetUsersAsync();

        return Ok(result);
    }

    [HttpPut("users/{userId}/status")]
    public async Task<IActionResult>
    UpdateUserStatus(
        int userId,
        UpdateUserStatusDto request)
    {
        await _adminService
            .UpdateUserStatusAsync(
                userId,
                request);

        return Ok(new
        {
            message =
                "User status updated successfully."
        });
    }

    [HttpPut(
    "therapists/{therapistId}/verification")]
    public async Task<IActionResult>
    UpdateTherapistVerification(
        int therapistId,
        UpdateTherapistVerificationDto request)
    {
        await _adminService
            .UpdateTherapistVerificationAsync(
                therapistId,
                request);

        return Ok(new
        {
            message =
                "Therapist verification updated."
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
}