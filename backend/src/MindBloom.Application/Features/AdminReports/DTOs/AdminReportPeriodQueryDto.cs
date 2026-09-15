namespace MindBloom.Application.Features.AdminReports.DTOs;

public class AdminReportPeriodQueryDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }
}