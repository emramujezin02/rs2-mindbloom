using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TherapistsController : ControllerBase
{
    private readonly ITherapistService _therapistService;

    public TherapistsController(
        ITherapistService therapistService)
    {
        _therapistService = therapistService;
    }

    [Authorize(Roles = "Therapist")]
    [HttpPost]
    public async Task<IActionResult> Create(
        CreateTherapistDto request)
    {
        var userId = int.Parse(
            User.FindFirstValue(ClaimTypes.NameIdentifier)!);

        var result =
            await _therapistService.CreateAsync(
                userId,
                request);

        return Ok(result);
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var result =
            await _therapistService.GetAllAsync();

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpPost("{therapistId}/availability")]
    public async Task<IActionResult> AddAvailability(
        int therapistId,
        CreateAvailabilityDto request)
    {
        await _therapistService.AddAvailabilityAsync(
            therapistId,
            request);

        return Ok();
    }

    [HttpGet("{therapistId}/availability")]
    public async Task<IActionResult> GetAvailabilities(
        int therapistId)
    {
        var result =
            await _therapistService
                .GetAvailabilitiesAsync(therapistId);

        return Ok(result);
    }

    [HttpGet("search")]
    public async Task<IActionResult>
    Search(
        [FromQuery] SearchTherapistsDto request)
    {
        var result =
            await _therapistService
                .SearchAsync(request);

        return Ok(result);
    }

    [HttpPost("filter")]
    public async Task<IActionResult> Filter(
    TherapistFilterDto filter)
    {
        var result =
            await _therapistService
                .FilterAsync(filter);

        return Ok(result);
    }

    [HttpPut("profile")]
    [Authorize(Roles = "Therapist")]
    public async Task<IActionResult>
    UpdateProfile(
        UpdateTherapistProfileDto request)
    {
        var therapistUserId =
            int.Parse(
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier)!);

        await _therapistService
            .UpdateProfileAsync(
                therapistUserId,
                request);

        return Ok(new
        {
            message =
                "Therapist profile updated successfully."
        });
    }

    [HttpGet("{id}")]
    public async Task<IActionResult>
    GetById(int id)
    {
        var result =
            await _therapistService
                .GetByIdAsync(id);

        return Ok(result);
    }

    [HttpDelete("availability/{availabilityId}")]
    public async Task<IActionResult>
    DeleteAvailability(
        int availabilityId)
    {
        var userId =
    int.Parse(
        User.FindFirst(
            ClaimTypes.NameIdentifier)!.Value);

        await _therapistService
            .DeleteAvailabilityAsync(
                userId,
                availabilityId);

        return Ok(
            "Availability deleted successfully.");
    }

    [HttpGet("dashboard")]
    [Authorize(Roles = "Therapist")]
    public async Task<IActionResult>
    GetDashboard()
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!.Value);

        var result =
            await _therapistService
                .GetDashboardAsync(userId);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpPost("unavailable-dates")]
    public async Task<IActionResult>
    AddUnavailableDate(
        CreateUnavailableDateDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _therapistService
            .AddUnavailableDateAsync(
                userId,
                request);

        return Ok(new
        {
            message =
                "Unavailable date added successfully."
        });
    }

    [HttpGet("{therapistId}/unavailable-dates")]
    public async Task<IActionResult>
    GetUnavailableDates(
        int therapistId)
    {
        var result =
            await _therapistService
                .GetUnavailableDatesAsync(
                    therapistId);

        return Ok(result);
    }


    [Authorize(Roles = "Therapist")]
    [HttpDelete(
    "unavailable-dates/{id}")]
    public async Task<IActionResult>
    DeleteUnavailableDate(
        int id)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _therapistService
            .DeleteUnavailableDateAsync(
                userId,
                id);

        return Ok(new
        {
            message =
                "Unavailable date deleted successfully."
        });
    }

    [Authorize(Roles = "Therapist")]
    [HttpPost("documents")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult>
    UploadDocument(
        [FromForm] UploadTherapistDocumentDto request)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _therapistService
            .UploadDocumentAsync(
                userId,
                request.File);

        return Ok(new
        {
            message =
                "Document uploaded successfully."
        });
    }

    [HttpGet("{therapistId}/documents")]
    public async Task<IActionResult>
    GetDocuments(
        int therapistId)
    {
        var result =
            await _therapistService
                .GetDocumentsAsync(
                    therapistId);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpDelete("documents/{id}")]
    public async Task<IActionResult>
    DeleteDocument(
        int id)
    {
        var userId =
            int.Parse(
                User.FindFirst(
                    ClaimTypes.NameIdentifier)!
                .Value);

        await _therapistService
            .DeleteDocumentAsync(
                userId,
                id);

        return Ok(new
        {
            message =
                "Document deleted successfully."
        });
    }
}