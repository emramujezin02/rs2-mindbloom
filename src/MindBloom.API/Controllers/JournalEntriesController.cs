using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.JournalEntries.DTOs;
using MindBloom.Application.Features.JournalEntries.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
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

    [Authorize(
        Roles = RoleConstants.Client)]
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

    [Authorize(Roles = RoleConstants.Client)]
    [HttpGet("mine")]
    public async Task<IActionResult> Mine(
    [FromQuery]
    JournalEntryPagingQueryDto query)
    {
        var userId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .GetMineAsync(
                    userId,
                    query.PageNumber,
                    query.PageSize);

        return Ok(result);
    }

    [Authorize(
        Roles = RoleConstants.Client)]
    [HttpGet("{id:int}")]
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

    [Authorize(
        Roles = RoleConstants.Client)]
    [HttpPut("{id:int}")]
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

    [Authorize(
        Roles = RoleConstants.Client)]
    [HttpDelete("{id:int}")]
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

    [Authorize(Roles = RoleConstants.Therapist)]
    [HttpGet("clients/{clientId:int}/history")]
    public async Task<IActionResult>
    GetClientHistory(
        int clientId,
        [FromQuery]
        JournalEntryPagingQueryDto query)
    {
        var therapistUserId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .GetClientHistoryForTherapistAsync(
                    therapistUserId,
                    clientId,
                    query.PageNumber,
                    query.PageSize);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Therapist)]
    [HttpGet(
    "clients/{clientId:int}/trend")]
    public async Task<IActionResult>
    GetClientTrend(
        int clientId,
        [FromQuery]
        JournalEntryTrendQueryDto query)
    {
        var therapistUserId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .GetClientTrendForTherapistAsync(
                    therapistUserId,
                    clientId,
                    query.Days);

        return Ok(result);
    }

    [Authorize(Roles = RoleConstants.Therapist)]
    [HttpGet(
    "clients/{clientId:int}/analytics")]
    public async Task<IActionResult>
    GetClientAnalytics(
        int clientId,
        [FromQuery]
        JournalEntryTrendQueryDto query)
    {
        var therapistUserId =
            GetAuthenticatedUserId();

        var result =
            await _journalEntryService
                .GetClientTrendForTherapistAsync(
                    therapistUserId,
                    clientId,
                    query.Days);

        return Ok(result);
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