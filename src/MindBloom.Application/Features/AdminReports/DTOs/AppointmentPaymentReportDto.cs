namespace MindBloom.Application.Features.AdminReports.DTOs;

public class AppointmentPaymentReportDto
{
    public int TotalPaymentRecords { get; set; }

    public int PaidPaymentsCount { get; set; }

    public int UnpaidAppointmentsCount { get; set; }

    public int RefundRequestedCount { get; set; }

    public int RefundedPaymentsCount { get; set; }

    public int FailedRefundsCount { get; set; }

    public decimal GrossRevenue { get; set; }

    public decimal RefundedAmount { get; set; }

    public decimal NetRevenue { get; set; }
}