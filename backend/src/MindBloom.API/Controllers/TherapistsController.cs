using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using MindBloom.Shared.Constants;
using Microsoft.AspNetCore.RateLimiting;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public class TherapistsController : ControllerBase
{
    private readonly ITherapistService _therapistService;

    public TherapistsController(
        ITherapistService therapistService)
    {
        _therapistService = therapistService;
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpPost]
    public async Task<IActionResult> Create(
        CreateTherapistDto request)
    {
        var result =
            await _therapistService.CreateAsync(
                GetCurrentUserId(),
                request);

        return StatusCode(
    StatusCodes.Status201Created,
    result);
    }

    [AllowAnonymous]
    [EnableRateLimiting(
    RateLimitPolicyConstants
        .PublicSearch)]
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var result =
            await _therapistService.GetAllAsync();

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpPost("availability")]
    public async Task<IActionResult> AddAvailability(
        CreateAvailabilityDto request)
    {
        await _therapistService
            .AddAvailabilityAsync(
                GetCurrentUserId(),
                request);

        return NoContent();
    }

    [AllowAnonymous]
    [HttpGet("{therapistId}/availability")]
    public async Task<IActionResult> GetAvailabilities(
        int therapistId)
    {
        var result =
            await _therapistService
                .GetAvailabilitiesAsync(therapistId);

        return Ok(result);
    }

    [AllowAnonymous]
    [EnableRateLimiting(
    RateLimitPolicyConstants
        .PublicSearch)]
    [HttpGet("search")]
    public async Task<IActionResult> Search(
        [FromQuery] SearchTherapistsDto request)
    {
        var result =
            await _therapistService
                .SearchAsync(request);

        return Ok(result);
    }

    [AllowAnonymous]
    [EnableRateLimiting(
    RateLimitPolicyConstants
        .PublicSearch)]
    [HttpPost("filter")]
    public async Task<IActionResult> Filter(
        [FromBody] TherapistFilterDto filter)
    {
        var result =
            await _therapistService
                .FilterAsync(filter);

        return Ok(result);
    }

    [AllowAnonymous]
    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(
        int id)
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

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpDelete("availability/{availabilityId}")]
    public async Task<IActionResult>
    DeleteAvailability(
        int availabilityId)
    {
        await _therapistService
            .DeleteAvailabilityAsync(
                GetCurrentUserId(),
                availabilityId);

        return NoContent();
    }

    [HttpGet("dashboard")]
    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    public async Task<IActionResult>
    GetDashboard()
    {
        var result =
            await _therapistService
                .GetDashboardAsync(GetCurrentUserId());

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpPost("unavailable-dates")]
    public async Task<IActionResult>
    AddUnavailableDate(
        CreateUnavailableDateDto request)
    {
        await _therapistService
            .AddUnavailableDateAsync(
                GetCurrentUserId(),
                request);

        return NoContent();
    }

    [AllowAnonymous]
    [HttpGet("{therapistId}/unavailable-dates")]
    public async Task<IActionResult> GetUnavailableDates(
        int therapistId,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10,
        [FromQuery] DateTime? fromUtc = null,
        [FromQuery] DateTime? toUtc = null)
    {
        var result =
            await _therapistService
                .GetUnavailableDatesAsync(
                    therapistId,
                    pageNumber,
                    pageSize,
                    fromUtc,
                    toUtc);

        return Ok(result);
    }


    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpDelete(
    "unavailable-dates/{id}")]
    public async Task<IActionResult>
    DeleteUnavailableDate(
        int id)
    {

        await _therapistService
            .DeleteUnavailableDateAsync(
                GetCurrentUserId(),
                id);

        return NoContent();
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [EnableRateLimiting(
    RateLimitPolicyConstants.Uploads)]
    [HttpPost("documents")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    public async Task<IActionResult>
        UploadDocument(
            [FromForm]
        UploadTherapistDocumentDto request)
    {
        await _therapistService
            .UploadDocumentAsync(
                GetCurrentUserId(),
                request.File);

        return Ok(new
        {
            message =
                "Document uploaded successfully."
        });
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOnly)]
    [HttpGet("{therapistId}/documents")]
    public async Task<IActionResult> GetDocuments(
        int therapistId,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10)
    {
        var result =
            await _therapistService
                .GetDocumentsAsync(
                    therapistId,
                    pageNumber,
                    pageSize);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpDelete("documents/{id}")]
    public async Task<IActionResult>
    DeleteDocument(
        int id)
    {
        await _therapistService
            .DeleteDocumentAsync(
                GetCurrentUserId(),
                id);

        return NoContent();
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpGet("clients")]
    public async Task<IActionResult>
    GetClients(
        [FromQuery] string? search,
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10)
    {
        var result =
            await _therapistService
                .GetClientsAsync(
                    GetCurrentUserId(),
                    search,
                    pageNumber,
                    pageSize);

        return Ok(result);
    }
    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpGet("clients/{clientId:int}")]
    public async Task<IActionResult>
        GetClientDetails(
            int clientId)
    {


        var result =
            await _therapistService
                .GetClientDetailsAsync(
                    GetCurrentUserId(),
                    clientId);

        return Ok(result);
    }

    [Authorize(
        Policy =
            AuthorizationPolicyConstants
                .AdminOnly)]
    [HttpGet(
        "documents/{documentId:int}/download")]
    public async Task<IActionResult>
        DownloadDocument(
            int documentId)
    {
        var userId =
            GetCurrentUserId();

        var document =
            await _therapistService
                .DownloadDocumentAsync(
                    userId,
                    documentId);

        return File(
            document.Content,
            document.ContentType,
            document.FileName);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpGet("profile")]
    public async Task<ActionResult<TherapistProfileDto>>
    GetProfile()
    {
        var profile =
            await _therapistService
                .GetProfileAsync(GetCurrentUserId());

        return Ok(profile);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpPut("profile")]
    public async Task<IActionResult>
    UpdateProfile(
        [FromBody]
        UpdateTherapistProfileDto request)
    {
        await _therapistService
            .UpdateProfileAsync(
                GetCurrentUserId(),
                request);

        return NoContent();
    }

    [Authorize(
        Policy =
            AuthorizationPolicyConstants.TherapistOnly)]
    [EnableRateLimiting(
    RateLimitPolicyConstants.Uploads)]
    [HttpPost("profile/image")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<
        ActionResult<TherapistProfileImageDto>>
        UploadProfileImage(
            [FromForm]
        UploadTherapistProfileImageDto request)
    {
        var result =
            await _therapistService
                .UploadProfileImageAsync(
                    GetCurrentUserId(),
                    request.File);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.TherapistOnly)]
    [HttpDelete("profile/image")]
    public async Task<IActionResult>
DeleteProfileImage()
    {
        await _therapistService
            .DeleteProfileImageAsync(
                GetCurrentUserId());

        return NoContent();
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
