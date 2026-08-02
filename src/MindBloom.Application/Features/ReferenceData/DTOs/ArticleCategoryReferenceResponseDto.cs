namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class ArticleCategoryReferenceResponseDto
{
    public int Id { get; set; }

    public string Name { get; set; } =
        string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; }

    public int ArticleCount { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? UpdatedAtUtc { get; set; }
}