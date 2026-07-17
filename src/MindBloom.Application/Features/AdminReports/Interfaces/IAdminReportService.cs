using MindBloom.Application.Features.AdminReports.DTOs;

namespace MindBloom.Application.Features.AdminReports.Interfaces;

public interface IAdminReportService
{
    Task<AppointmentRevenueReportDto>
        GetAppointmentRevenueReportAsync(
            AdminReportPeriodQueryDto query,
            CancellationToken cancellationToken = default);

    Task<TherapistPerformanceReportDto>
        GetTherapistPerformanceReportAsync(
            AdminReportPeriodQueryDto query,
            CancellationToken cancellationToken = default);
}