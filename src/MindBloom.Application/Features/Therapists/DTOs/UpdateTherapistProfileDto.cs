namespace MindBloom.Application.Features.Therapists.DTOs;

public class UpdateTherapistProfileDto
{
    public string Biography { get; set; } = string.Empty;

    public string Specialization { get; set; } = string.Empty;

    public int ExperienceYears { get; set; }
}