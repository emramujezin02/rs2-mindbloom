namespace MindBloom.Application.Features.Reviews.DTOs;

public class PublicReviewDto
{
    public string? AuthorGender { get; set; }
    public int? AuthorAge { get; set; }
    public int Id { get; set; }

    public string ClientInitials { get; set; } =
        string.Empty;

    public int Rating { get; set; }

    public string Comment { get; set; } =
        string.Empty;

    public int TherapistId { get; set; }

    public string TherapistName { get; set; } =
        string.Empty;

    public DateTime CreatedAtUtc { get; set; }
}
