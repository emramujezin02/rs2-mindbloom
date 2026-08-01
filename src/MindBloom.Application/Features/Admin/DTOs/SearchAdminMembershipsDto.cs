using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Admin.DTOs;

public class SearchAdminMembershipsDto
{
    private int _pageNumber = 1;

    private int _pageSize = 10;

    public string? Search { get; set; }

    public int? ClientId { get; set; }

    public int? TherapistId { get; set; }

    public DateTime? ExpiresFromUtc { get; set; }

    public DateTime? ExpiresToUtc { get; set; }

    public MembershipPlanType? PlanType
    {
        get;
        set;
    }

    public string? MembershipStatus
    {
        get;
        set;
    }

    public PaymentStatus? PaymentStatus
    {
        get;
        set;
    }

    public int PageNumber
    {
        get => _pageNumber;

        set => _pageNumber =
            value < 1
                ? 1
                : value;
    }

    public int PageSize
    {
        get => _pageSize;

        set => _pageSize =
            value switch
            {
                < 1 => 10,
                > 100 => 100,
                _ => value
            };
    }
}