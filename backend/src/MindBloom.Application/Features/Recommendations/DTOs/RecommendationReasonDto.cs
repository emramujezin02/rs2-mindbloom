namespace MindBloom.Application.Recommendations.DTOs;

public sealed class RecommendationReasonDto
{
    public string Criterion { get; set; } = string.Empty;

    public decimal AwardedPoints { get; set; }

    public decimal MaximumPoints { get; set; }

    public string Explanation { get; set; } = string.Empty;
}