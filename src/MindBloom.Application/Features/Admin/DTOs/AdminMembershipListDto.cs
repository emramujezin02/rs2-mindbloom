namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminMembershipListDto
{
    public int Id { get; set; }

    public int ClientId { get; set; }

    public string ClientName { get; set; }
        = string.Empty;

    public string ClientEmail { get; set; }
        = string.Empty;

    public int TherapistId { get; set; }

    public string TherapistName { get; set; }
        = string.Empty;

    public string TherapistEmail { get; set; }
        = string.Empty;

    public string PlanType { get; set; }
        = string.Empty;

    public string MembershipStatus { get; set; }
        = string.Empty;

    public int TotalSessions { get; set; }

    public int RemainingSessions { get; set; }

    public int UsedSessions { get; set; }

    public int ReservedSessions { get; set; }

    public int ConsumedSessions { get; set; }

    public int RestoredSessions { get; set; }

    public decimal Price { get; set; }

    public bool IsActive { get; set; }

    public string PaymentStatus { get; set; }
        = string.Empty;

    public DateTime? PurchasedAtUtc
    {
        get;
        set;
    }

    public DateTime? ExpiresAtUtc
    {
        get;
        set;
    }

    public DateTime CreatedAtUtc
    {
        get;
        set;
    }
}