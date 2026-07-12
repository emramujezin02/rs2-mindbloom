namespace MindBloom.Application.Features.Reviews.DTOs;

public class CreateReviewDto
{
    public int AppointmentId { get; set; }

    public int Rating { get; set; }

    public string Comment { get; set; } =
        string.Empty;
}