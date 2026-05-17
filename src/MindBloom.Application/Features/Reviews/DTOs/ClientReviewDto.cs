namespace MindBloom.Application.Features.Reviews.DTOs;

public class ClientReviewDto
{
    public int Id { get; set; }

    public int TherapistId { get; set; }

    public string TherapistName { get; set; } = string.Empty;

    public int Rating { get; set; }

    public string Comment { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public string? TherapistReply { get; set; }

    public DateTime? TherapistReplyCreatedAtUtc{get;set;}
}