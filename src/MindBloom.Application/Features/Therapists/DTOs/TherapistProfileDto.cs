namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistProfileDto
{
    public int TherapistId { get; set; }

    public int UserId { get; set; }

    public string FirstName { get; set; } = string.Empty;

    public string LastName { get; set; } = string.Empty;

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string? PhoneNumber { get; set; }

    public string Biography { get; set; } = string.Empty;

    public string Specialization { get; set; } = string.Empty;

    public int ExperienceYears { get; set; }

    public decimal HourlyRate { get; set; }

    public string Location { get; set; } = string.Empty;

    public List<string> Languages { get; set; } = [];

    public string? ProfileImageUrl { get; set; }

    public string Country { get; set; } = string.Empty;

    public string City { get; set; } = string.Empty;

    public string Address { get; set; } = string.Empty;

    public bool OffersOnline { get; set; }

    public bool OffersInPerson { get; set; }

    public string VerificationStatus { get; set; } = string.Empty;

    public List<AvailabilityResponseDto> Availabilities { get; set; } = [];
}