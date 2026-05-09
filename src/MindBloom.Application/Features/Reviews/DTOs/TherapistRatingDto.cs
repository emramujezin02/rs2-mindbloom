namespace MindBloom.Application.Features.Reviews.DTOs;

public class TherapistRatingDto
{
    public int TherapistId { get; set; }

    public double AverageRating { get; set; }

    public int TotalReviews { get; set; }
}