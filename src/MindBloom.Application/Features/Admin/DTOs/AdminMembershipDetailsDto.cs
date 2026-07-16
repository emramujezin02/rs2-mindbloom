namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminMembershipDetailsDto
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

    public DateTime? UpdatedAtUtc
    {
        get;
        set;
    }

    public AdminMembershipPaymentDto?
        Payment
    {
        get;
        set;
    }

    public List<AdminMembershipUsageDto>
        Usages
    {
        get;
        set;
    } = new();
}

public class AdminMembershipPaymentDto
{
    public int Id { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; }
        = string.Empty;

    public string Status { get; set; }
        = string.Empty;

    public string StripePaymentIntentId
    {
        get;
        set;
    } = string.Empty;

    public DateTime? PaidAtUtc
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

public class AdminMembershipUsageDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public string AppointmentStatus
    {
        get;
        set;
    } = string.Empty;

    public DateTime AppointmentStartUtc
    {
        get;
        set;
    }

    public DateTime AppointmentEndUtc
    {
        get;
        set;
    }

    public string Status { get; set; }
        = string.Empty;

    public DateTime UsedAtUtc
    {
        get;
        set;
    }

    public DateTime? ReservedAtUtc
    {
        get;
        set;
    }

    public DateTime? ConsumedAtUtc
    {
        get;
        set;
    }

    public DateTime? RestoredAtUtc
    {
        get;
        set;
    }

    public string? ResolutionReason
    {
        get;
        set;
    }

    public DateTime CreatedAtUtc
    {
        get;
        set;
    }

    public DateTime? UpdatedAtUtc
    {
        get;
        set;
    }
}