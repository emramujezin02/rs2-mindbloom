namespace MindBloom.Application.Features.Memberships.DTOs;

public class MembershipResponseDto
{
    public int Id { get; set; }

    public int TherapistId { get; set; }

    public string TherapistName { get; set; } = string.Empty;

    public string PlanType { get; set; } = string.Empty;

    public string PlanName { get; set; } = string.Empty;

    public int TotalSessions { get; set; }

    public int RemainingSessions { get; set; }

    public int UsedSessions { get; set; }

    public decimal Price { get; set; }

    public bool IsActive { get; set; }

    public bool IsPaid { get; set; }

    public bool IsExpired { get; set; }

    public string PaymentStatus { get; set; } = string.Empty;

    public DateTime? PurchasedAtUtc { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }
}