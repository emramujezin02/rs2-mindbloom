namespace MindBloom.Application.Features.AdminReports.DTOs;

public class AppointmentRevenueReportDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public DateTime GeneratedAtUtc { get; set; }

    public string GeneratedByAdmin { get; set; } =
        string.Empty;

    public int? TherapistId { get; set; }

    public string? TherapistName { get; set; }

    public string? AppointmentStatusFilter { get; set; }

    public string? AppointmentTypeFilter { get; set; }

    public string? PaymentStatusFilter { get; set; }

    public int TotalAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public int CancelledAppointments { get; set; }

    public int UniqueClientsCount { get; set; }

    public int UniqueTherapistsCount { get; set; }

    public IReadOnlyList<AppointmentStatusReportItemDto>
        AppointmentsByStatus
    { get; set; } =
        Array.Empty<AppointmentStatusReportItemDto>();

    public AppointmentPaymentReportDto PaymentSummary
    {
        get;
        set;
    } = new();

    public IReadOnlyList<AppointmentRevenueReportItemDto>
        Appointments
    { get; set; } =
        Array.Empty<AppointmentRevenueReportItemDto>();
}