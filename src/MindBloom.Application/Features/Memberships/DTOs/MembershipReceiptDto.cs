namespace MindBloom.Application.Features.Memberships.DTOs;

public class MembershipReceiptDto
{
    public int MembershipId { get; set; }

    public int PaymentId { get; set; }

    public string InvoiceNumber { get; set; } = string.Empty;

    public string ClientName { get; set; } = string.Empty;

    public string TherapistName { get; set; } = string.Empty;

    public string PlanType { get; set; } = string.Empty;

    public int TotalSessions { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; } = string.Empty;

    public string PaymentStatus { get; set; } = string.Empty;

    public DateTime PaidAtUtc { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }
}