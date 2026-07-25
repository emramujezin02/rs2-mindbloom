namespace MindBloom.Domain.Entities;

public class Article : BaseEntity
{
    public string Title { get; set; } =
        string.Empty;

    public string Description { get; set; } =
        string.Empty;

    public string Content { get; set; } =
        string.Empty;

    public string? ImageUrl { get; set; }

    public int AuthorUserId { get; set; }

    public ApplicationUser AuthorUser { get; set; } =
        null!;

    public int? TherapistId { get; set; }

    public Therapist? Therapist { get; set; }

    public int? ArticleCategoryId { get; set; }

    public ArticleCategory? ArticleCategory { get; set; }

    public DateTime PublishedAtUtc { get; set; }

    public bool IsPublished { get; set; } = true;
}