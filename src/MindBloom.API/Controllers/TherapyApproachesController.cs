using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using MindBloom.Infrastructure
    .Persistence.Context;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Policy = "AuthenticatedUser")]
public sealed class TherapyApproachesController
    : ControllerBase
{
    private readonly ApplicationDbContext
        _context;

    public TherapyApproachesController(
        ApplicationDbContext context)
    {
        _context = context;
    }

    [AllowAnonymous]
    [HttpGet("public")]
    public async Task<IActionResult>
        GetPublic()
    {
        var result =
            await _context
                .TherapyApproaches
                .AsNoTracking()
                .Where(x =>
                    x.IsActive &&
                    !x.IsDeleted)
                .OrderBy(x =>
                    x.Name)
                .Select(x => new
                {
                    x.Id,
                    x.Name,
                    Description =
                        x.Description
                        ?? string.Empty,

                    IconUrl =
                        (string?)null,

                    x.IsActive
                })
                .ToListAsync();

        return Ok(result);
    }
}