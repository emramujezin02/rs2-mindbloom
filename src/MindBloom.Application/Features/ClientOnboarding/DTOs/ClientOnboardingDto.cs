namespace MindBloom.Application
    .Features.ClientOnboarding.DTOs;

public sealed class ClientOnboardingDto
{
    public bool HasCompletedOnboarding
    {
        get;
        set;
    }

    public DateTime? CompletedAtUtc
    {
        get;
        set;
    }

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

    public string CurrentSensitiveDataProcessingVersion
    {
        get;
        set;
    } = string.Empty;

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

    public bool HasAcceptedSensitiveDataProcessing
    {
        get;
        set;
    }

    public string? SensitiveDataProcessingVersion
    {
        get;
        set;
    }

    public DateTime? SensitiveDataProcessingAcceptedAtUtc
    {
        get;
        set;
    }

    public string SensitiveDataUsageExplanation
    {
        get;
        set;
    } = string.Empty;
}