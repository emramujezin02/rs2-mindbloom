namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistResponseDto
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public string FullName { get; set; } = string.Empty;

    public string Email { get; set; } = string.Empty;

    public string Specialization { get; set; } = string.Empty;

    public string Biography { get; set; } = string.Empty;

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }

    public double AverageRating { get; set; }

    public int TotalReviews { get; set; }

    public string VerificationStatus { get; set; } = string.Empty;

    public string? VerificationNotes { get; set; }

    public string? ProfileImageUrl { get; set; }

    public string Country { get; set; } = string.Empty;

    public string City { get; set; } = string.Empty;

    public string Address { get; set; } = string.Empty;

    public bool OffersOnline { get; set; }

    public bool OffersInPerson { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    public List<string> TherapyApproaches { get; set; } = [];
}