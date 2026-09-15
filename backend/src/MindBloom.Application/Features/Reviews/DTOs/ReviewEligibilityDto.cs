namespace MindBloom.Application.Features.Reviews.DTOs;

public class ReviewEligibilityDto
{
    public int AppointmentId { get; set; }

    public bool CanReview { get; set; }

    public string Message { get; set; } = string.Empty;

    public int? ExistingReviewId { get; set; }

    public string? ModerationStatus { get; set; }
}