namespace MindBloom.Application.Features.Admin.DTOs;

public class TherapistVerificationAuditDto
{
    public int Id { get; set; }

    public string AdminName { get; set; }
        = string.Empty;

    public string PreviousStatus { get; set; }
        = string.Empty;

    public string NewStatus { get; set; }
        = string.Empty;

    public string? Notes { get; set; }

    public DateTime ChangedAtUtc { get; set; }
}