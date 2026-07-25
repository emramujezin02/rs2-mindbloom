namespace MindBloom.Application.Features.Payments.DTOs;

public class PaymentHistoryDto
{
    public int Id { get; set; }

    public string PaymentType { get; set; }
        = string.Empty;

    public int? AppointmentId { get; set; }

    public int? MembershipId { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; }
        = string.Empty;

    public string Purpose { get; set; }
        = string.Empty;

    public string Status { get; set; }
        = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? PaidAtUtc { get; set; }

    public string TherapistName { get; set; }
        = string.Empty;

    public string? RefundReason { get; set; }

    public DateTime? RefundRequestedAtUtc
    {
        get;
        set;
    }

    public DateTime? RefundedAtUtc
    {
        get;
        set;
    }

    public string? RefundFailureReason
    {
        get;
        set;
    }
}