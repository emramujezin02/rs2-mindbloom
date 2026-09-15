namespace MindBloom.Application.Features.Users.DTOs;

public class UpdateUserProfileDto
{
    public string FirstName { get; set; } =
        string.Empty;

    public string LastName { get; set; } =
        string.Empty;

    public string? PhoneNumber { get; set; }

    public DateTime DateOfBirth { get; set; }

    public string? Location { get; set; }

    public string? PreferredTherapistGender { get; set; }

    public string? PreferredSessionType { get; set; }

    public decimal? MinimumPricePerSession { get; set; }

    public decimal? MaximumPricePerSession { get; set; }

    public List<string> PreferredLanguages { get; set; } = [];
}