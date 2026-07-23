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

        return StatusCode(
    StatusCodes.Status201Created,
    result);
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

        return NoContent();
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

    [HttpGet("{id}")]
    public async Task<IActionResult>
 GetById(int id)
    {
        int? currentUserId = null;

        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (int.TryParse(
                userIdValue,
                out var parsedUserId))
        {
            currentUserId =
                parsedUserId;
        }

        var result =
            await _therapistService
                .GetByIdAsync(
                    id,
                    currentUserId);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
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

        return NoContent();
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

        return NoContent();
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

        return NoContent();
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

        return NoContent();
    }

    [Authorize(Roles = "Therapist")]
    [HttpGet("clients")]
    public async Task<IActionResult>
    GetClients(
        [FromQuery] string? search)
    {
        var therapistUserId =
            int.Parse(
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier)!);

        var result =
            await _therapistService
                .GetClientsAsync(
                    therapistUserId,
                    search);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpGet("clients/{clientId:int}")]
    public async Task<IActionResult>
        GetClientDetails(
            int clientId)
    {
        var therapistUserId =
            int.Parse(
                User.FindFirstValue(
                    ClaimTypes.NameIdentifier)!);

        var result =
            await _therapistService
                .GetClientDetailsAsync(
                    therapistUserId,
                    clientId);

        return Ok(result);
    }

    [Authorize(Roles = "Therapist")]
    [HttpGet("profile")]
    public async Task<ActionResult<TherapistProfileDto>>
    GetProfile()
    {
        var userId =
            GetCurrentUserId();

        var profile =
            await _therapistService
                .GetProfileAsync(userId);

        return Ok(profile);
    }

    [Authorize(Roles = "Therapist")]
    [HttpPut("profile")]
    public async Task<IActionResult>
    UpdateProfile(
        [FromBody]
        UpdateTherapistProfileDto request)
    {
        var userId =
            GetCurrentUserId();

        await _therapistService
            .UpdateProfileAsync(
                userId,
                request);

        return NoContent();
    }

    [Authorize(Roles = "Therapist")]
    [HttpPost("profile/image")]
    [Consumes("multipart/form-data")]
    public async Task<
ActionResult<TherapistProfileImageDto>>
UploadProfileImage(
    [FromForm]
    UploadTherapistProfileImageDto request)
    {
        var userId =
            GetCurrentUserId();

        var result =
            await _therapistService
                .UploadProfileImageAsync(
                    userId,
                    request.File);

        return Ok(result);
    }

    private int GetCurrentUserId()
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Authenticated user identifier is missing or invalid.");
        }

        return userId;
    }
}