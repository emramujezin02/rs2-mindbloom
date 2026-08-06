using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using System.Security.Claims;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public class AppointmentsController : ControllerBase
{
    private readonly IAppointmentService _appointmentService;

    public AppointmentsController(
        IAppointmentService appointmentService)
    {
        _appointmentService = appointmentService;
    }

    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    [HttpPost]
    public async Task<IActionResult> Create(
        CreateAppointmentDto request)
    {


        var result =
            await _appointmentService.CreateAsync(
                GetCurrentUserId(),
                request);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    [HttpGet("mine")]
    public async Task<IActionResult> Mine()
    {


        var result =
            await _appointmentService
                .GetMyAppointmentsAsync(GetCurrentUserId());

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    [HttpGet("{appointmentId:int}")]
    public async Task<IActionResult>
    GetClientAppointmentDetails(
        int appointmentId)
    {


        var result =
            await _appointmentService
                .GetClientAppointmentDetailsAsync(
                    GetCurrentUserId(),
                    appointmentId);

        return Ok(result);
    }

    [HttpGet("therapist")]
    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    public async Task<IActionResult>
    GetTherapistAppointments()
    {

        var result =
            await _appointmentService
                .GetTherapistAppointmentsAsync(
                    GetCurrentUserId());

        return Ok(result);
    }

    [HttpPut("status")]
    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    public async Task<IActionResult>
    UpdateStatus(
        UpdateAppointmentStatusDto request)
    {

        await _appointmentService
            .UpdateStatusAsync(
                GetCurrentUserId(),
                request);

        return NoContent();
    }

    [HttpPut("{appointmentId}/cancel")]
    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    public async Task<IActionResult> CancelAppointment(
    int appointmentId,
    CancelAppointmentDto request)
    {


        await _appointmentService
            .CancelAppointmentAsync(
                GetCurrentUserId(),
                appointmentId,
                request);

        return NoContent();
    }

    [HttpGet("therapist/stats")]
    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    public async Task<IActionResult>
    GetTherapistStats()
    {


        var result =
            await _appointmentService
                .GetTherapistStatsAsync(
                    GetCurrentUserId());

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpPost("notes")]
    public async Task<IActionResult>
    AddAppointmentNote(
        CreateAppointmentNoteDto request)
    {


        await _appointmentService
            .AddAppointmentNoteAsync(
                GetCurrentUserId(),
                request);

        return Ok(new
        {
            message =
                "Appointment note added successfully."
        });
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpGet("{appointmentId}/notes")]
    public async Task<IActionResult>
    GetAppointmentNote(
        int appointmentId)
    {

        var result =
            await _appointmentService
                .GetAppointmentNoteAsync(
                    GetCurrentUserId(),
                    appointmentId);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    [HttpGet("client-dashboard")]
    public async Task<IActionResult>
    GetClientDashboard()
    {
 

        var result =
            await _appointmentService
                .GetClientDashboardAsync(
                    GetCurrentUserId());

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpPut("{appointmentId}/meeting-link")]
    public async Task<IActionResult>
    UpdateMeetingLink(
        int appointmentId,
        UpdateMeetingLinkDto request)
    {


        await _appointmentService
            .UpdateMeetingLinkAsync(
                GetCurrentUserId(),
                appointmentId,
                request);

        return NoContent();
    }

    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    [HttpGet(
    "therapist/{therapistId}/occupied-slots")]
    public async Task<IActionResult>
    GetOccupiedSlots(
        int therapistId,
        [FromQuery] DateTime date)
    {
        var result =
            await _appointmentService
                .GetOccupiedSlotsAsync(
                    therapistId,
                    date);

        return Ok(result);
    }

    private int GetCurrentUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId) ||
            userId <= 0)
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is missing or invalid.");
        }

        return userId;
    }
}