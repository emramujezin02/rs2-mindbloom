namespace MindBloom.Application.Features.Reviews.DTOs;

public class ClientReviewDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public int TherapistId { get; set; }

    public string TherapistName { get; set; } = string.Empty;

    public int Rating { get; set; }

    public string Comment { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public bool IsApproved { get; set; }

    public string ModerationStatus { get; set; } = string.Empty;

    public bool CanEdit { get; set; }

    public string? ModerationReason { get; set; }

    public string? TherapistReply { get; set; }

    public DateTime? TherapistReplyCreatedAtUtc { get; set; }
}