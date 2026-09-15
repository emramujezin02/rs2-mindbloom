namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistClientReviewDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public int Rating { get; set; }

    public string Comment { get; set; }
        = string.Empty;

    public bool IsApproved { get; set; }

    public string ModerationStatus { get; set; }
        = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public string? TherapistReply { get; set; }

    public DateTime? TherapistReplyCreatedAtUtc
    {
        get;
        set;
    }
}