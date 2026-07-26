namespace MindBloom.Application
    .Features.ClientOnboarding.DTOs;

public sealed class SaveClientOnboardingDto
{
    public List<string> AssessmentFocusAreas
    {
        get;
        set;
    } = [];

    public string? PreferredTherapistGender
    {
        get;
        set;
    }

    public string? PreferredSessionType
    {
        get;
        set;
    }

    public List<string> PreferredLanguages
    {
        get;
        set;
    } = [];

    public decimal? MinimumPricePerSession
    {
        get;
        set;
    }

    public decimal? MaximumPricePerSession
    {
        get;
        set;
    }

    public string? Location
    {
        get;
        set;
    }

    public List<DayOfWeek> PreferredDays
    {
        get;
        set;
    } = [];

    public List<int> PreferredTherapyApproachIds
    {
        get;
        set;
    } = [];

    public bool CompleteOnboarding
    {
        get;
        set;
    } = true;
}