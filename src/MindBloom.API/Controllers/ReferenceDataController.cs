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

    [Authorize]
    [HttpGet("therapy-approaches/active")]
    public async Task<ActionResult<
    IReadOnlyList<TherapyApproachResponseDto>>>
    GetActiveTherapyApproaches(
        CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .GetActiveTherapyApproachesAsync(
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpGet("therapy-approaches")]
    public async Task<ActionResult<
        TherapyApproachPagedResponseDto>>
        GetTherapyApproaches(
            [FromQuery]
        TherapyApproachQueryDto query,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .GetTherapyApproachesAsync(
                    query,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpGet("therapy-approaches/{id:int}")]
    public async Task<ActionResult<
        TherapyApproachResponseDto>>
        GetTherapyApproach(
            int id,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .GetTherapyApproachByIdAsync(
                    id,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPost("therapy-approaches")]
    public async Task<ActionResult<
        TherapyApproachResponseDto>>
        CreateTherapyApproach(
            [FromBody]
        CreateTherapyApproachDto request,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .CreateTherapyApproachAsync(
                    request,
                    cancellationToken);

        return CreatedAtAction(
            nameof(GetTherapyApproach),
            new
            {
                id = result.Id
            },
            result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPut("therapy-approaches/{id:int}")]
    public async Task<ActionResult<
        TherapyApproachResponseDto>>
        UpdateTherapyApproach(
            int id,
            [FromBody]
        UpdateTherapyApproachDto request,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .UpdateTherapyApproachAsync(
                    id,
                    request,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPut("therapy-approaches/{id:int}/status")]
    public async Task<ActionResult<
        TherapyApproachResponseDto>>
        UpdateTherapyApproachStatus(
            int id,
            [FromBody]
        UpdateTherapyApproachStatusDto request,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .UpdateTherapyApproachStatusAsync(
                    id,
                    request,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpDelete("therapy-approaches/{id:int}")]
    public async Task<IActionResult>
        DeleteTherapyApproach(
            int id,
            CancellationToken cancellationToken)
    {
        await _referenceDataService
            .DeleteTherapyApproachAsync(
                id,
                cancellationToken);

        return NoContent();
    }

    [Authorize]
    [HttpGet("article-categories/active")]
    public async Task<ActionResult<
    IReadOnlyList<ArticleCategoryReferenceResponseDto>>>
    GetActiveArticleCategories(
        CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .GetActiveArticleCategoriesAsync(
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpGet("article-categories")]
    public async Task<ActionResult<
        ArticleCategoryReferencePagedResponseDto>>
        GetArticleCategories(
            [FromQuery]
        ArticleCategoryReferenceQueryDto query,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .GetArticleCategoriesAsync(
                    query,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpGet("article-categories/{id:int}")]
    public async Task<ActionResult<
        ArticleCategoryReferenceResponseDto>>
        GetArticleCategory(
            int id,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .GetArticleCategoryByIdAsync(
                    id,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPost("article-categories")]
    public async Task<ActionResult<
        ArticleCategoryReferenceResponseDto>>
        CreateArticleCategory(
            [FromBody]
        CreateArticleCategoryReferenceDto request,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .CreateArticleCategoryAsync(
                    request,
                    cancellationToken);

        return CreatedAtAction(
            nameof(GetArticleCategory),
            new
            {
                id = result.Id
            },
            result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPut("article-categories/{id:int}")]
    public async Task<ActionResult<
        ArticleCategoryReferenceResponseDto>>
        UpdateArticleCategory(
            int id,
            [FromBody]
        UpdateArticleCategoryReferenceDto request,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .UpdateArticleCategoryAsync(
                    id,
                    request,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpPut("article-categories/{id:int}/status")]
    public async Task<ActionResult<
        ArticleCategoryReferenceResponseDto>>
        UpdateArticleCategoryStatus(
            int id,
            [FromBody]
        UpdateArticleCategoryReferenceStatusDto request,
            CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .UpdateArticleCategoryStatusAsync(
                    id,
                    request,
                    cancellationToken);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Admin)]
    [HttpDelete("article-categories/{id:int}")]
    public async Task<IActionResult>
        DeleteArticleCategory(
            int id,
            CancellationToken cancellationToken)
    {
        await _referenceDataService
            .DeleteArticleCategoryAsync(
                id,
                cancellationToken);

        return NoContent();
    }
}