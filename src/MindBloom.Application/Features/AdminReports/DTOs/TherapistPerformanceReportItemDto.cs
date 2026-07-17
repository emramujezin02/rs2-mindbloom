namespace MindBloom.Application.Features.AdminReports.DTOs;

public class TherapistPerformanceReportItemDto
{
    public int TherapistId { get; set; }

    public int UserId { get; set; }

    public string TherapistName { get; set; } = string.Empty;

    public string Specialization { get; set; } = string.Empty;

    public int TotalAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public int UniqueClientsCount { get; set; }

    public decimal GrossRevenue { get; set; }

    public decimal RefundedAmount { get; set; }

    public decimal NetRevenue { get; set; }

    public double? AverageRating { get; set; }

    public int ReviewCount { get; set; }
}