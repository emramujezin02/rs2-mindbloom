namespace MindBloom.Application.Features.Auth.DTOs;

public sealed class RegisterTherapistRequestDto
{
    public string FirstName { get; set; } =
        string.Empty;

    public string LastName { get; set; } =
        string.Empty;

    public string Email { get; set; } =
        string.Empty;

    public string Username { get; set; } =
        string.Empty;

    public string Password { get; set; } =
        string.Empty;

    public DateTime DateOfBirth { get; set; }

    public string Gender { get; set; } =
        string.Empty;

    public string Specialization { get; set; } =
        string.Empty;

    public string Biography { get; set; } =
        string.Empty;

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }

    public string Country { get; set; } =
        string.Empty;

    public string City { get; set; } =
        string.Empty;

    public string Address { get; set; } =
        string.Empty;

    public bool OffersOnline { get; set; }

    public bool OffersInPerson { get; set; }

    public bool AcceptPrivacyPolicy
    {
        get;
        set;
    }

    public string PrivacyPolicyVersion
    {
        get;
        set;
    } = string.Empty;

    public bool AcceptTermsOfService
    {
        get;
        set;
    }

    public string TermsOfServiceVersion
    {
        get;
        set;
    } = string.Empty;
}