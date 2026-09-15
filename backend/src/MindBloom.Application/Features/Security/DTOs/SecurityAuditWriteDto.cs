namespace MindBloom.Application.Features.Security.DTOs;

public sealed class SecurityAuditWriteDto
{
    public int? UserId { get; set; }

    public string EventType { get; set; }
        = string.Empty;

    public bool IsSuccessful { get; set; }

    public string? FailureReason { get; set; }

    public string? ResourceType { get; set; }

    public string? ResourceId { get; set; }

    public string? CorrelationId { get; set; }
}