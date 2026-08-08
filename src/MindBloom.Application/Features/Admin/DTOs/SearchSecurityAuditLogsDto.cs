namespace MindBloom.Application.Features.Admin.DTOs;

public sealed class SearchSecurityAuditLogsDto
{
    public int PageNumber { get; set; } = 1;

    public int PageSize { get; set; } = 20;

    public int? UserId { get; set; }

    public string? EventType { get; set; }

    public string? ResourceType { get; set; }

    public bool? IsSuccessful { get; set; }

    public DateTime? FromUtc { get; set; }

    public DateTime? ToUtc { get; set; }

    public string? Search { get; set; }
}