namespace MindBloom.Application.Features.Admin.DTOs;

public sealed class SecurityAuditLogDto
{
    public int Id { get; set; }

    public int? UserId { get; set; }

    public string EventType { get; set; }
        = string.Empty;

    public bool IsSuccessful { get; set; }

    public string? FailureReason { get; set; }

    public string? ResourceType { get; set; }

    public string? ResourceId { get; set; }

    public string? IpAddress { get; set; }

    public string? UserAgent { get; set; }

    public string? CorrelationId { get; set; }

    public DateTime OccurredAtUtc { get; set; }
}