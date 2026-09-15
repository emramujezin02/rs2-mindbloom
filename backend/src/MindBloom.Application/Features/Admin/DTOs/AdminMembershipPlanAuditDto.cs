namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminMembershipPlanAuditDto
{
    public int Id { get; set; }

    public string Action { get; set; }
        = string.Empty;

    public string ChangedByName { get; set; }
        = string.Empty;

    public string? PreviousValues { get; set; }

    public string? NewValues { get; set; }

    public string? Reason { get; set; }

    public DateTime ChangedAtUtc { get; set; }
}