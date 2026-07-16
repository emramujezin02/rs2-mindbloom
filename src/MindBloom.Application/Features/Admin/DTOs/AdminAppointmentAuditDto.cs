namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminAppointmentAuditDto
{
    public int Id { get; set; }

    public string? PreviousStatus { get; set; }

    public string NewStatus { get; set; }
        = string.Empty;

    public string Action { get; set; }
        = string.Empty;

    public string? Reason { get; set; }

    public int ChangedByUserId { get; set; }

    public string ChangedByUserName { get; set; }
        = string.Empty;

    public string ChangedByUserEmail { get; set; }
        = string.Empty;

    public DateTime ChangedAtUtc { get; set; }
}