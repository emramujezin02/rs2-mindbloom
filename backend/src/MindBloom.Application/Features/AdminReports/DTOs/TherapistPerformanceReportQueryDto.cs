using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.AdminReports.DTOs;

public class TherapistPerformanceReportQueryDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public int? TherapistId { get; set; }

    public int MinimumAppointments { get; set; }

    public TherapistVerificationStatus? TherapistStatus { get; set; }
}