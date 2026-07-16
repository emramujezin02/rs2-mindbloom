namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminPaymentListDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public string ClientName { get; set; }
        = string.Empty;

    public string ClientEmail { get; set; }
        = string.Empty;

    public string TherapistName { get; set; }
        = string.Empty;

    public decimal Amount { get; set; }

    public string Currency { get; set; }
        = "USD";

    public string Status { get; set; }
        = string.Empty;

    public string AppointmentStatus { get; set; }
        = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? PaidAtUtc { get; set; }

    public DateTime? RefundedAtUtc { get; set; }

    public bool CanRefund { get; set; }
}