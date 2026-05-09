namespace MindBloom.Application.Features.Reviews.DTOs;

public class CreateReviewDto
{
    public int TherapistId { get; set; }

    public int Rating { get; set; }

    public string Comment { get; set; } = null!;
}