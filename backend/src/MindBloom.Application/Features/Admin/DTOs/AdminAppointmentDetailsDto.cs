namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminAppointmentDetailsDto
{
    public int Id { get; set; }

    public int ClientId { get; set; }

    public int ClientUserId { get; set; }

    public string ClientName { get; set; }
        = string.Empty;

    public string ClientEmail { get; set; }
        = string.Empty;

    public int TherapistId { get; set; }

    public int TherapistUserId { get; set; }

    public string TherapistName { get; set; }
        = string.Empty;

    public string TherapistEmail { get; set; }
        = string.Empty;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Status { get; set; }
        = string.Empty;

    public string Type { get; set; }
        = string.Empty;

    public decimal Price { get; set; }

    public bool IsPaid { get; set; }

    public string? PaymentStatus { get; set; }

    public decimal? PaymentAmount { get; set; }

    public string? StripePaymentIntentId { get; set; }

    public string? RefundStatus { get; set; }

    public string? RefundReason { get; set; }

    public string? MeetingLink { get; set; }

    public string? Location { get; set; }

    public string? Notes { get; set; }

    public bool HasMembershipUsage { get; set; }

    public string? MembershipUsageStatus { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }

    public bool CanAdminCancel { get; set; }

    public List<AdminAppointmentAuditDto>
        AuditHistory
    { get; set; }
            = new();
}