using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AppointmentsController : ControllerBase
{
    private readonly IAppointmentService _appointmentService;

    public AppointmentsController(
        IAppointmentService appointmentService)
    {
        _appointmentService = appointmentService;
    }

    [Authorize(Roles = "Client")]
    [HttpPost]
    public async Task<IActionResult> Create(
        CreateAppointmentDto request)
    {
        var userId = int.Parse(
            User.FindFirstValue(
                ClaimTypes.NameIdentifier)!);

        var result =
            await _appointmentService.CreateAsync(
                userId,
                request);

        return Ok(result);
    }

    [Authorize(Roles = "Client")]
    [HttpGet("mine")]
    public async Task<IActionResult> Mine()
    {
        var userId = int.Parse(
            User.FindFirstValue(
                ClaimTypes.NameIdentifier)!);

        var result =
            await _appointmentService
                .GetMyAppointmentsAsync(userId);

        return Ok(result);
    }

    [HttpGet("therapist")]
    [Authorize(Roles = "Therapist")]
    public async Task<IActionResult>
    GetTherapistAppointments()
    {
        var therapistUserId =
            int.Parse(
                User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        var result =
            await _appointmentService
                .GetTherapistAppointmentsAsync(
                    therapistUserId);

        return Ok(result);
    }

    [HttpPut("status")]
    [Authorize(Roles = "Therapist")]
    public async Task<IActionResult>
    UpdateStatus(
        UpdateAppointmentStatusDto request)
    {
        var therapistUserId =
            int.Parse(
                User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

        await _appointmentService
            .UpdateStatusAsync(
                therapistUserId,
                request);

        return Ok("Appointment updated.");
    }

    [HttpPut("{appointmentId}/cancel")]
    [Authorize(Roles = "Client")]
    public async Task<IActionResult> CancelAppointment(
    int appointmentId,
    CancelAppointmentDto request)
    {
        var userId = int.Parse(
            User.FindFirstValue(
                ClaimTypes.NameIdentifier)!);

        await _appointmentService
            .CancelAppointmentAsync(
                userId,
                appointmentId,
                request);

        return Ok(new
        {
            message = "Appointment cancelled successfully."
        });
    }

    [HttpGet("therapist/stats")]
    [Authorize(Roles = "Therapist")]
    public async Task<IActionResult>
    GetTherapistStats()
    {
        var therapistUserId =
            int.Parse(
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier)!);

        var result =
            await _appointmentService
                .GetTherapistStatsAsync(
                    therapistUserId);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpPost("notes")]
    public async Task<IActionResult>
    AddAppointmentNote(
        CreateAppointmentNoteDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _appointmentService
            .AddAppointmentNoteAsync(
                userId,
                request);

        return Ok(new
        {
            message =
                "Appointment note added successfully."
        });
    }

    [Authorize(Roles = "Therapist")]
    [HttpGet("{appointmentId}/notes")]
    public async Task<IActionResult>
    GetAppointmentNote(
        int appointmentId)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        var result =
            await _appointmentService
                .GetAppointmentNoteAsync(
                    userId,
                    appointmentId);

        return Ok(result);
    }

    [Authorize(Roles = "Client")]
    [HttpGet("client-dashboard")]
    public async Task<IActionResult>
    GetClientDashboard()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        var result =
            await _appointmentService
                .GetClientDashboardAsync(
                    userId);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpPut("{appointmentId}/meeting-link")]
    public async Task<IActionResult>
    UpdateMeetingLink(
        int appointmentId,
        UpdateMeetingLinkDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _appointmentService
            .UpdateMeetingLinkAsync(
                userId,
                appointmentId,
                request);

        return Ok(new
        {
            message =
                "Meeting link updated successfully."
        });
    }
}