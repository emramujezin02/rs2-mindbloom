namespace MindBloom.Application.Features.Reviews.DTOs;

public class ReviewResponseDto
{
    public int Id { get; set; }

    public string ClientName { get; set; } = null!;

    public int Rating { get; set; }

    public string Comment { get; set; } = null!;

    public DateTime CreatedAtUtc { get; set; }
}