namespace MindBloom.Application.Features.AdminReports.DTOs;

public class TherapistPerformanceReportDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public int TherapistCount { get; set; }

    public int TotalCompletedAppointments { get; set; }

    public int TotalUniqueClients { get; set; }

    public decimal TotalGrossRevenue { get; set; }

    public decimal TotalRefundedAmount { get; set; }

    public decimal TotalNetRevenue { get; set; }

    public IReadOnlyList<TherapistPerformanceReportItemDto>
        Therapists
    { get; set; } = Array.Empty<TherapistPerformanceReportItemDto>();
}