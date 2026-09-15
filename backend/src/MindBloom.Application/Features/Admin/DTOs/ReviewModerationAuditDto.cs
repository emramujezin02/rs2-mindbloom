namespace MindBloom.Application.Features.Admin.DTOs;

public class ReviewModerationAuditDto
{
    public int Id { get; set; }

    public string Action { get; set; } = string.Empty;

    public string AdminName { get; set; } = string.Empty;

    public string AdminEmail { get; set; } = string.Empty;

    public string Reason { get; set; } = string.Empty;

    public DateTime PerformedAtUtc { get; set; }
}