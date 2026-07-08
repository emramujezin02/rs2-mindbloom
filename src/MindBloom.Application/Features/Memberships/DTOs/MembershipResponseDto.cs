namespace MindBloom.Application.Features.Memberships.DTOs;

public class MembershipResponseDto
{
    public int Id { get; set; }

    public int TherapistId { get; set; }

    public string TherapistName { get; set; } = string.Empty;

    public string PlanType { get; set; } = string.Empty;

    public int TotalSessions { get; set; }

    public int RemainingSessions { get; set; }

    public decimal Price { get; set; }

    public bool IsActive { get; set; }

    public DateTime PurchasedAtUtc { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }
}