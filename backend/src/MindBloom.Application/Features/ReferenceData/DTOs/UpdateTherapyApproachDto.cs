namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class UpdateTherapyApproachDto
{
    public int? FeaturedArticleId { get; set; }
    // Preserve the existing link for older API clients; explicit true + null removes it.
    public bool UpdateFeaturedArticle { get; set; }
    public string Name { get; set; } =
        string.Empty;

    public string? Description { get; set; }
}
