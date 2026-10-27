using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Application.Features.ReferenceData.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = AuthorizationPolicyConstants.AuthenticatedUser)]
public sealed class TherapyApproachesController
    : ControllerBase
{
    private readonly IReferenceDataService
        _referenceDataService;

    public TherapyApproachesController(
        IReferenceDataService referenceDataService)
    {
        _referenceDataService = referenceDataService;
    }

    [AllowAnonymous]
    [HttpGet("public")]
    public async Task<ActionResult<IReadOnlyList<TherapyApproachResponseDto>>>
        GetPublic(CancellationToken cancellationToken)
    {
        var result =
            await _referenceDataService
                .GetActiveTherapyApproachesAsync(
                    cancellationToken);

        return Ok(result);
    }
}
