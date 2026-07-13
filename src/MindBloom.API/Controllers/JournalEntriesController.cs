using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.JournalEntries.DTOs;
using MindBloom.Application.Features.JournalEntries.Interfaces;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Client")]
public class JournalEntriesController
    : ControllerBase
{
    private readonly IJournalEntryService
        _journalEntryService;

    public JournalEntriesController(
        IJournalEntryService journalEntryService)
    {
        _journalEntryService =
            journalEntryService;
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        CreateJournalEntryDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .CreateAsync(
                    userId,
                    request);

        return Ok(result);
    }

    [HttpGet("mine")]
    public async Task<IActionResult> Mine(
        [FromQuery] int pageNumber = 1,
        [FromQuery] int pageSize = 10)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .GetMineAsync(
                    userId,
                    pageNumber,
                    pageSize);

        return Ok(result);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(
        int id)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .GetByIdAsync(
                    userId,
                    id);

        return Ok(result);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(
        int id,
        UpdateJournalEntryDto request)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .UpdateAsync(
                    userId,
                    id,
                    request);

        return Ok(result);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(
        int id)
    {
        var userId =
            GetAuthenticatedUserId();

        await _journalEntryService
            .DeleteAsync(
                userId,
                id);

        return Ok(new
        {
            message =
                "Journal entry deleted successfully."
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