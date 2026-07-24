using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features
    .PrivateJournalEntries.DTOs;
using MindBloom.Application.Features
    .PrivateJournalEntries.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(
    Roles = RoleConstants.Client)]
public sealed class PrivateJournalEntriesController
    : ControllerBase
{
    private readonly IPrivateJournalEntryService
        _privateJournalEntryService;

    public PrivateJournalEntriesController(
        IPrivateJournalEntryService
            privateJournalEntryService)
    {
        _privateJournalEntryService =
            privateJournalEntryService;
    }

    [HttpPost]
    public async Task<IActionResult>
        Create(
            CreatePrivateJournalEntryDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _privateJournalEntryService
                .CreateAsync(
                    userId,
                    request);

        return Ok(result);
    }

    [HttpGet("mine")]
    public async Task<IActionResult>
        GetMine(
            [FromQuery]
            PrivateJournalEntryQueryDto query)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _privateJournalEntryService
                .GetMineAsync(
                    userId,
                    query);

        return Ok(result);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult>
        GetById(
            int id)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _privateJournalEntryService
                .GetByIdAsync(
                    userId,
                    id);

        return Ok(result);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult>
        Update(
            int id,
            UpdatePrivateJournalEntryDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _privateJournalEntryService
                .UpdateAsync(
                    userId,
                    id,
                    request);

        return Ok(result);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult>
        Delete(
            int id)
    {
        var userId =
            GetAuthenticatedUserId();

        await _privateJournalEntryService
            .DeleteAsync(
                userId,
                id);

        return Ok(new
        {
            message =
                "Private journal entry deleted successfully."
        });
    }

    private int GetAuthenticatedUserId()
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
}