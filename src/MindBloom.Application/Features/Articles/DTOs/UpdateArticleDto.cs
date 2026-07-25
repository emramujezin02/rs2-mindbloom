namespace MindBloom.Application.Features.Articles.DTOs;

public class UpdateArticleDto
{
    public string Title { get; set; } =
        string.Empty;

    public string Description { get; set; } =
        string.Empty;

    public string Content { get; set; } =
        string.Empty;

    public string? ImageUrl { get; set; }

    public int ArticleCategoryId { get; set; }

    public bool IsPublished { get; set; }
}