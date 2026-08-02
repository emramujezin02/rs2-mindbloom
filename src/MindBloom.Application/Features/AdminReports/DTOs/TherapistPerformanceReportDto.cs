namespace MindBloom.Application.Features.AdminReports.DTOs;

public class TherapistPerformanceReportDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public DateTime GeneratedAtUtc { get; set; }

    public int? TherapistIdFilter { get; set; }

    public string? TherapistNameFilter { get; set; }

    public int MinimumAppointmentsFilter { get; set; }

    public string? TherapistStatusFilter { get; set; }

    public int TherapistCount { get; set; }

    public int TotalAppointments { get; set; }

    public int TotalCompletedAppointments { get; set; }

    public int TotalCancelledAppointments { get; set; }

    public int TotalUniqueClients { get; set; }

    public decimal TotalGrossRevenue { get; set; }

    public decimal TotalRefundedAmount { get; set; }

    public decimal TotalNetRevenue { get; set; }

    public IReadOnlyList<TherapistPerformanceReportItemDto>
        Therapists
    { get; set; } = Array.Empty<TherapistPerformanceReportItemDto>();
}