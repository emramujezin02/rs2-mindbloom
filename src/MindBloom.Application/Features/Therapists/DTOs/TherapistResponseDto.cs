namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistResponseDto
{
    public int Id { get; set; }

    public int UserId { get; set; }

    public string FullName { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string Specialization { get; set; } = null!;

    public string Biography { get; set; } = null!;

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }
    public double AverageRating { get; set; }

    public int TotalReviews { get; set; }
}