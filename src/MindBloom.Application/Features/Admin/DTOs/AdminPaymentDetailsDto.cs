namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminPaymentDetailsDto
{
    public int Id { get; set; }

    public string PaymentType { get; set; }
        = string.Empty;

    public int? AppointmentId { get; set; }

    public int? MembershipId { get; set; }

    public int ClientId { get; set; }

    public int ClientUserId { get; set; }

    public string ClientName { get; set; }
        = string.Empty;

    public string ClientEmail { get; set; }
        = string.Empty;

    public int TherapistId { get; set; }

    public string TherapistName { get; set; }
        = string.Empty;

    public string TherapistEmail { get; set; }
        = string.Empty;

    public decimal Amount { get; set; }

    public string Currency { get; set; }
        = string.Empty;

    public string Status { get; set; }
        = string.Empty;

    public string Purpose { get; set; }
        = string.Empty;

    public string StripePaymentIntentId { get; set; }
        = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? PaidAtUtc { get; set; }

    public string? StripeRefundId { get; set; }

    public string? RefundReason { get; set; }

    public DateTime? RefundRequestedAtUtc { get; set; }

    public DateTime? RefundedAtUtc { get; set; }

    public string? RefundFailureReason { get; set; }

    public string? AppointmentStatus { get; set; }

    public DateTime? AppointmentStartUtc { get; set; }

    public DateTime? AppointmentEndUtc { get; set; }

    public string? AppointmentType { get; set; }

    public bool? AppointmentIsPaid { get; set; }

    public string? MembershipPlanType { get; set; }

    public int? TotalSessions { get; set; }

    public int? RemainingSessions { get; set; }

    public bool? MembershipIsActive { get; set; }

    public DateTime? MembershipExpiresAtUtc { get; set; }

    public bool CanRefund { get; set; }

    public string? RefundUnavailableReason { get; set; }
}