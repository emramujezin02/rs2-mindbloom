namespace MindBloom.Application.Features.AdminReports.DTOs;

public class AppointmentRevenueReportDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public int TotalAppointments { get; set; }

    public int UniqueClientsCount { get; set; }

    public int UniqueTherapistsCount { get; set; }

    public IReadOnlyList<AppointmentStatusReportItemDto>
        AppointmentsByStatus
    { get; set; } = Array.Empty<AppointmentStatusReportItemDto>();

    public AppointmentPaymentReportDto PaymentSummary { get; set; } =
        new();
}