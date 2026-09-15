using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.AdminReports.DTOs;

public class AppointmentRevenueReportQueryDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public int? TherapistId { get; set; }

    public AppointmentStatus? AppointmentStatus { get; set; }

    public AppointmentType? AppointmentType { get; set; }

    public PaymentStatus? PaymentStatus { get; set; }
}