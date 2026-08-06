using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Shared.Constants;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/admin/audit-logs")]
[Authorize(Policy = AuthorizationPolicyConstants.AdminOnly)]
public class AdminAuditController
    : ControllerBase
{
    private readonly IAdminAuditService
        _auditService;

    public AdminAuditController(
        IAdminAuditService auditService)
    {
        _auditService =
            auditService;
    }

    [HttpGet]
    [ProducesResponseType(
        typeof(
            PagedResponse<
                AdminAuditLogDto>),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
        PagedResponse<AdminAuditLogDto>>>
        GetAuditLogs(
            [FromQuery]
            SearchAdminAuditLogsDto request,
            CancellationToken cancellationToken)
    {
        var result =
            await _auditService
                .GetAuditLogsAsync(
                    request,
                    cancellationToken);

        return Ok(result);
    }

    [HttpGet("filter-options")]
    [ProducesResponseType(
        typeof(
            AdminAuditFilterOptionsDto),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
        AdminAuditFilterOptionsDto>>
        GetFilterOptions(
            CancellationToken cancellationToken)
    {
        var result =
            await _auditService
                .GetFilterOptionsAsync(
                    cancellationToken);

        return Ok(result);
    }

    [HttpPost]
    [HttpPut]
    [HttpPatch]
    [HttpDelete]
    public IActionResult ModificationNotAllowed()
    {
        return StatusCode(
            StatusCodes
                .Status405MethodNotAllowed,
            new
            {
                message =
                    "Audit records are read-only and cannot be created, edited or deleted through the API."
            });
    }
}