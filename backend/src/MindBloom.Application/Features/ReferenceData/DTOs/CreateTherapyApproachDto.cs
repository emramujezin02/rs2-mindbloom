namespace MindBloom.Application.Features.ReferenceData.DTOs;

public class CreateTherapyApproachDto
{
    public int? FeaturedArticleId { get; set; }
    public string Name { get; set; } =
        string.Empty;

    public string? Description { get; set; }

    public bool IsActive { get; set; } = true;
}
