namespace MindBloom.Application
    .Recommendations.DTOs;

public sealed class TherapistRecommendationRequestDto
{
    public List<int> PreferredSpecializationIds
    {
        get;
        set;
    } = [];

    public List<int> PreferredTherapyApproachIds
    {
        get;
        set;
    } = [];

    public List<string> AssessmentFocusAreas
    {
        get;
        set;
    } = [];

    public List<DayOfWeek> PreferredDays
    {
        get;
        set;
    } = [];

    public decimal? MaximumPricePerSession
    {
        get;
        set;
    }

    public int? MinimumExperienceYears
    {
        get;
        set;
    }

    public int Take { get; set; } = 10;
}