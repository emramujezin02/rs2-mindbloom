namespace MindBloom.Application.Features.Reviews.DTOs;

public class UpdateReviewDto
{
    // Omitted by older clients: preserve the saved consent.
    public bool? ShareAuthorDemographics { get; set; }
    public int Rating { get; set; }

    public string Comment { get; set; } = string.Empty;
}
