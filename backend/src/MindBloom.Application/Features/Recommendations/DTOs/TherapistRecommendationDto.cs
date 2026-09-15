namespace MindBloom.Application.Recommendations.DTOs;

public sealed class TherapistRecommendationDto
{
    public int TherapistId { get; set; }

    public int UserId { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Specialization { get; set; } = string.Empty;

    public decimal PricePerSession { get; set; }

    public int ExperienceYears { get; set; }

    public string? ProfileImageUrl { get; set; }

    public decimal AverageRating { get; set; }

    public int ReviewCount { get; set; }

    public bool IsFavorite { get; set; }

    public bool HasPreviousAppointment { get; set; }

    public List<DayOfWeek> AvailableDays { get; set; } = [];

    public decimal Score { get; set; }

    public int MatchPercentage { get; set; }

    public List<RecommendationReasonDto> Reasons { get; set; } = [];
}