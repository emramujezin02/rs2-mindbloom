namespace MindBloom.Application.Features.Articles.DTOs;

public class ArticleResponseDto
{
    public int Id { get; set; }

    public string Title { get; set; } =
        string.Empty;

    public string Description { get; set; } =
        string.Empty;

    public string Content { get; set; } =
        string.Empty;

    public string ImageUrl { get; set; } =
        string.Empty;

    public int AuthorUserId { get; set; }

    public int? TherapistId { get; set; }

    public string AuthorName { get; set; } =
        string.Empty;

    public DateTime? PublishedAtUtc { get; set; }

    public bool IsPublished { get; set; }

    public int? ArticleCategoryId { get; set; }

    public string ArticleCategoryName { get; set; } =
        string.Empty;
}