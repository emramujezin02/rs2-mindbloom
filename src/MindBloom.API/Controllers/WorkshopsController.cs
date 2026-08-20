using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MindBloom.Application.Features.Workshops.DTOs;
using MindBloom.Application.Features.Workshops.Interfaces;
using MindBloom.Shared.Constants;
using MindBloom.API.Idempotency;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public class WorkshopsController : ControllerBase
{
    private readonly IWorkshopService
        _workshopService;

    public WorkshopsController(
        IWorkshopService workshopService)
    {
        _workshopService =
            workshopService;
    }

    [AllowAnonymous]
    [EnableRateLimiting(
    RateLimitPolicyConstants
        .PublicSearch)]
    [HttpGet]
    public async Task<IActionResult>
        GetPublic(
            [FromQuery]
            WorkshopQueryDto query)
    {
        var clientUserId =
            TryGetAuthenticatedUserId();

        var result =
            await _workshopService
                .GetPublicAsync(
                    query,
                    clientUserId);

        return Ok(result);
    }

    [AllowAnonymous]
    [HttpGet("{id}")]
    public async Task<IActionResult>
        GetById(
            int id)
    {
        var clientUserId =
            TryGetAuthenticatedUserId();

        var result =
            await _workshopService
                .GetPublicByIdAsync(
                    id,
                    clientUserId);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpGet("manage")]
    public async Task<IActionResult>
        GetManageList(
            [FromQuery]
            WorkshopQueryDto query)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _workshopService
                .GetManageListAsync(
                    userId,
                    isAdmin,
                    query);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpGet("{id}/registrations")]
    public async Task<IActionResult>
        GetRegistrations(
            int id,
            [FromQuery]
            int pageNumber = 1,
            [FromQuery]
            int pageSize = 10)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _workshopService
                .GetRegistrationsAsync(
                    userId,
                    isAdmin,
                    id,
                    pageNumber,
                    pageSize);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpPost]
    public async Task<IActionResult>
        Create(
            CreateWorkshopDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _workshopService
                .CreateAsync(
                    userId,
                    isAdmin,
                    request);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpPut("{id}")]
    public async Task<IActionResult>
        Update(
            int id,
            UpdateWorkshopDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _workshopService
                .UpdateAsync(
                    userId,
                    isAdmin,
                    id,
                    request);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpPut("{id}/status")]
    public async Task<IActionResult>
        UpdateStatus(
            int id,
            UpdateWorkshopStatusDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        var result =
            await _workshopService
                .UpdateStatusAsync(
                    userId,
                    isAdmin,
                    id,
                    request);

        return Ok(result);
    }

    [Authorize(Policy = AuthorizationPolicyConstants.AdminOrTherapist)]
    [HttpDelete("{id}")]
    public async Task<IActionResult>
        Delete(
            int id)
    {
        var userId =
            GetAuthenticatedUserId();

        var isAdmin =
            User.IsInRole(
                RoleConstants.Admin);

        await _workshopService
            .DeleteAsync(
                userId,
                isAdmin,
                id);

        return Ok(new
        {
            message =
                "Workshop deleted successfully."
        });
    }

    [Authorize(
        Policy =
            AuthorizationPolicyConstants
                .ClientOnly)]
    [HttpPost("{id}/register")]
    [RequireIdempotency]
    public async Task<IActionResult>
        Register(
            int id)
    {
        var userId =
            GetAuthenticatedUserId();

        await _workshopService
            .RegisterAsync(
                userId,
                id);

        return Ok(new
        {
            message =
                "You have successfully registered "
                + "for the workshop."
        });
    }

    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    [HttpDelete("{id}/registration")]
    public async Task<IActionResult>
        CancelRegistration(
            int id)
    {
        var userId =
            GetAuthenticatedUserId();

        await _workshopService
            .CancelRegistrationAsync(
                userId,
                id);

        return Ok(new
        {
            message =
                "Workshop registration cancelled successfully."
        });
    }

    [Authorize(Policy = AuthorizationPolicyConstants.ClientOnly)]
    [HttpGet("mine")]
    public async Task<IActionResult>
        GetMyRegistrations(
            [FromQuery]
            int pageNumber = 1,
            [FromQuery]
            int pageSize = 10)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _workshopService
                .GetMyRegistrationsAsync(
                    userId,
                    pageNumber,
                    pageSize);

        return Ok(result);
    }

    private int
        GetAuthenticatedUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                value,
                out var userId))
        {
            throw new UnauthorizedAccessException(
                "Invalid authenticated user.");
        }

        return userId;
    }

    private int?
        TryGetAuthenticatedUserId()
    {
        var value =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        return int.TryParse(
                value,
                out var userId)
            ? userId
            : null;
    }

    [Authorize(
        Policy =
            AuthorizationPolicyConstants.AdminOrTherapist)]
    [EnableRateLimiting(
    RateLimitPolicyConstants.Uploads)]
    [HttpPost("image")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(5 * 1024 * 1024)]
    public async Task<IActionResult>
        UploadImage(
            IFormFile file)
    {
        var result =
            await _workshopService
                .UploadImageAsync(file);

        return Ok(result);
    }
}