namespace MindBloom.Application.Features.AdminReports.DTOs;

public class AppointmentRevenueReportItemDto
{
    public int AppointmentId { get; set; }

    public string ClientName { get; set; } =
        string.Empty;

    public string TherapistName { get; set; } =
        string.Empty;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string AppointmentStatus { get; set; } =
        string.Empty;

    public string AppointmentType { get; set; } =
        string.Empty;

    public decimal Price { get; set; }

    public string PaymentStatus { get; set; } =
        "Unpaid";

    public decimal PaidAmount { get; set; }

    public decimal RefundedAmount { get; set; }
}