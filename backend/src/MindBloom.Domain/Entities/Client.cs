namespace MindBloom.Domain.Entities;

public class Client : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public ICollection<Appointment> Appointments { get; set; } = new List<Appointment>();
    public ICollection<WorkshopRegistration> WorkshopRegistrations{ get; set; } = new List<WorkshopRegistration>();
    public ICollection<MoodEntry> MoodEntries { get; set; } = new List<MoodEntry>();

    public string? Location { get; set; }

    public string? PreferredTherapistGender { get; set; }

    public string? PreferredSessionType { get; set; }

    public decimal? MinimumPricePerSession { get; set; }

    public decimal? MaximumPricePerSession { get; set; }

    public string? PreferredLanguages { get; set; }

    public string? AssessmentFocusAreas
    {
        get;
        set;
    }

    public string? PreferredDays
    {
        get;
        set;
    }

    public bool HasCompletedOnboarding
    {
        get;
        set;
    }

    public DateTime? OnboardingCompletedAtUtc
    {
        get;
        set;
    }

    public ICollection<ClientTherapyApproach>
        PreferredTherapyApproaches
    {
        get;
        set;
    } = new List<ClientTherapyApproach>();
}