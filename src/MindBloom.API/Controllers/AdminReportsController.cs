using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MindBloom.Application.Features.AdminReports.DTOs;
using MindBloom.Application.Features.AdminReports.Interfaces;
using System.Security.Claims;

namespace MindBloom.API.Controllers;

[ApiController]
[Route("api/admin/reports")]
[Authorize(Policy = "AdminOnly")]
public class AdminReportsController : ControllerBase
{
    private readonly IAdminReportService
        _adminReportService;

    public AdminReportsController(
        IAdminReportService adminReportService)
    {
        _adminReportService =
            adminReportService;
    }

    [HttpGet("dashboard")]
    [ProducesResponseType(
    typeof(AdminDashboardReportDto),
    StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminDashboardReportDto>>
    GetDashboardReport(
        [FromQuery]
        AdminDashboardReportQueryDto query,
        CancellationToken cancellationToken)
    {
        var result =
            await _adminReportService
                .GetDashboardReportAsync(
                    query,
                    cancellationToken);

        return Ok(result);
    }

    [HttpGet("appointments-revenue")]
    [ProducesResponseType(
        typeof(AppointmentRevenueReportDto),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
        AppointmentRevenueReportDto>>
        GetAppointmentRevenueReport(
            [FromQuery]
        AppointmentRevenueReportQueryDto query,
            CancellationToken cancellationToken)
    {
        var userIdValue =
            User.FindFirstValue(
                ClaimTypes.NameIdentifier);

        if (!int.TryParse(
                userIdValue,
                out var adminUserId))
        {
            return Unauthorized();
        }

        var result =
            await _adminReportService
                .GetAppointmentRevenueReportAsync(
                    adminUserId,
                    query,
                    cancellationToken);

        return Ok(result);
    }

    [HttpGet("therapist-performance")]
    [ProducesResponseType(
        typeof(TherapistPerformanceReportDto),
        StatusCodes.Status200OK)]
    public async Task<ActionResult<
        TherapistPerformanceReportDto>>
        GetTherapistPerformanceReport(
            [FromQuery]
        TherapistPerformanceReportQueryDto query,
            CancellationToken cancellationToken)
    {
        var result =
            await _adminReportService
                .GetTherapistPerformanceReportAsync(
                    query,
                    cancellationToken);

        return Ok(result);
    }
}