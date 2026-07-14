using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class Payment : BaseEntity
{
    public int AppointmentId { get; set; }

    public Appointment Appointment { get; set; } = null!;

    public decimal Amount { get; set; }

    public PaymentStatus Status { get; set; }

    public string StripePaymentIntentId { get; set; } = null!;

    public DateTime? PaidAtUtc { get; set; }

    public string? StripeRefundId { get; set; }

    public string? RefundReason { get; set; }

    public DateTime? RefundRequestedAtUtc { get; set; }

    public DateTime? RefundedAtUtc { get; set; }

    public string? RefundFailureReason { get; set; }
}