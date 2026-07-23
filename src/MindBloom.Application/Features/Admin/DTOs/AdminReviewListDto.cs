namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminReviewListDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public string ClientName { get; set; } = string.Empty;

    public string ClientEmail { get; set; } = string.Empty;

    public string TherapistName { get; set; } = string.Empty;

    public string TherapistEmail { get; set; } = string.Empty;

    public int Rating { get; set; }

    public string Comment { get; set; } = string.Empty;

    public bool HasTherapistReply { get; set; }

    public bool IsDeleted { get; set; }

    public bool IsApproved { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? ModeratedAtUtc { get; set; }
}