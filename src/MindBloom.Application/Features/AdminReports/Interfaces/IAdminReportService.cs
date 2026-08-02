using MindBloom.Application.Features.AdminReports.DTOs;

namespace MindBloom.Application.Features.AdminReports.Interfaces;

public interface IAdminReportService
{
    Task<AdminDashboardReportDto>
        GetDashboardReportAsync(
            AdminDashboardReportQueryDto query,
            CancellationToken cancellationToken = default);

    Task<AppointmentRevenueReportDto>
        GetAppointmentRevenueReportAsync(
            int authenticatedAdminUserId,
            AppointmentRevenueReportQueryDto query,
            CancellationToken cancellationToken = default);

    Task<TherapistPerformanceReportDto>
        GetTherapistPerformanceReportAsync(
            TherapistPerformanceReportQueryDto query,
            CancellationToken cancellationToken = default);
}