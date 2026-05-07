namespace MindBloom.Application.Features.Therapists.DTOs;

public class CreateTherapistDto
{
    public string Specialization { get; set; } = null!;

    public string Biography { get; set; } = null!;

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }
}