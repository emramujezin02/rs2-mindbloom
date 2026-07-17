using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Application.Features.ReferenceData.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/reference-data")]
public class ReferenceDataController : ControllerBase
{
    private readonly IReferenceDataService _referenceDataService;

    public ReferenceDataController(
        IReferenceDataService referenceDataService)
    {
        _referenceDataService = referenceDataService;
    }

    [Authorize]
    [HttpGet("therapist-specializations/active")]
    public async Task<ActionResult<
        IReadOnlyList<TherapistSpecializationResponseDto>>>
        GetActiveTherapistSpecializations(
            CancellationToken cancellationToken)
    {
        var result = await _referenceDataService
            .GetActiveTherapistSpecializationsAsync(
                cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpGet("therapist-specializations")]
    public async Task<ActionResult<
        TherapistSpecializationPagedResponseDto>>
        GetTherapistSpecializations(
            [FromQuery] TherapistSpecializationQueryDto query,
            CancellationToken cancellationToken)
    {
        var result = await _referenceDataService
            .GetTherapistSpecializationsAsync(
                query,
                cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpGet("therapist-specializations/{id:int}")]
    public async Task<ActionResult<
        TherapistSpecializationResponseDto>>
        GetTherapistSpecialization(
            int id,
            CancellationToken cancellationToken)
    {
        var result = await _referenceDataService
            .GetTherapistSpecializationByIdAsync(
                id,
                cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPost("therapist-specializations")]
    public async Task<ActionResult<
        TherapistSpecializationResponseDto>>
        CreateTherapistSpecialization(
            [FromBody] CreateTherapistSpecializationDto request,
            CancellationToken cancellationToken)
    {
        var result = await _referenceDataService
            .CreateTherapistSpecializationAsync(
                request,
                cancellationToken);

        return CreatedAtAction(
            nameof(GetTherapistSpecialization),
            new
            {
                id = result.Id
            },
            result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPut("therapist-specializations/{id:int}")]
    public async Task<ActionResult<
        TherapistSpecializationResponseDto>>
        UpdateTherapistSpecialization(
            int id,
            [FromBody] UpdateTherapistSpecializationDto request,
            CancellationToken cancellationToken)
    {
        var result = await _referenceDataService
            .UpdateTherapistSpecializationAsync(
                id,
                request,
                cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPut("therapist-specializations/{id:int}/status")]
    public async Task<ActionResult<
        TherapistSpecializationResponseDto>>
        UpdateTherapistSpecializationStatus(
            int id,
            [FromBody] UpdateTherapistSpecializationStatusDto request,
            CancellationToken cancellationToken)
    {
        var result = await _referenceDataService
            .UpdateTherapistSpecializationStatusAsync(
                id,
                request,
                cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpDelete("therapist-specializations/{id:int}")]
    public async Task<IActionResult>
        DeleteTherapistSpecialization(
            int id,
            CancellationToken cancellationToken)
    {
        await _referenceDataService
            .DeleteTherapistSpecializationAsync(
                id,
                cancellationToken);

        return NoContent();
    }
}