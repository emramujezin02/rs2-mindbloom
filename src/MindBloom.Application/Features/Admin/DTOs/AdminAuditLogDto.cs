namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminAuditLogDto
{
    public int Id { get; set; }

    public int? AdminUserId { get; set; }

    public string AdminName { get; set; }
        = string.Empty;

    public string AdminEmail { get; set; }
        = string.Empty;

    public string Action { get; set; }
        = string.Empty;

    public string EntityType { get; set; }
        = string.Empty;

    public string? EntityId { get; set; }

    public string HttpMethod { get; set; }
        = string.Empty;

    public string RequestPath { get; set; }
        = string.Empty;

    public DateTime OccurredAtUtc { get; set; }

    public string? PreviousValues { get; set; }

    public string? NewValues { get; set; }

    public string? IpAddress { get; set; }

    public string CorrelationId { get; set; }
        = string.Empty;

    public bool IsSuccessful { get; set; }

    public int StatusCode { get; set; }

    public string? ResultMessage { get; set; }
}