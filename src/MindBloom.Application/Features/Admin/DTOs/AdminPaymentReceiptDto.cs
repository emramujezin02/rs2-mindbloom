namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminPaymentReceiptDto
{
    public string InvoiceNumber { get; set; }
        = string.Empty;

    public int PaymentId { get; set; }

    public string PaymentType { get; set; }
        = string.Empty;

    public int? AppointmentId { get; set; }

    public int? MembershipId { get; set; }

    public string ClientName { get; set; }
        = string.Empty;

    public string ClientEmail { get; set; }
        = string.Empty;

    public string TherapistName { get; set; }
        = string.Empty;

    public decimal Amount { get; set; }

    public string Currency { get; set; }
        = string.Empty;

    public string Status { get; set; }
        = string.Empty;

    public string Purpose { get; set; }
        = string.Empty;

    public DateTime PaymentDateUtc { get; set; }

    public DateTime? AppointmentStartUtc { get; set; }

    public DateTime? AppointmentEndUtc { get; set; }

    public string StripePaymentIntentId { get; set; }
        = string.Empty;

    public string? StripeRefundId { get; set; }

    public string? RefundReason { get; set; }

    public DateTime? RefundedAtUtc { get; set; }
}