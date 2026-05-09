using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using System.Security.Claims;

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
}