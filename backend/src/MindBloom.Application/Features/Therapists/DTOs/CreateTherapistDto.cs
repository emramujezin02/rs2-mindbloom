namespace MindBloom.Application.Features.Therapists.DTOs;

public class CreateTherapistDto
{
    public string Specialization { get; set; } = string.Empty;

    public string Biography { get; set; } = string.Empty;

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }

    public string Country { get; set; } = string.Empty;

    public string City { get; set; } = string.Empty;

    public string Address { get; set; } = string.Empty;

    public bool OffersOnline { get; set; }

    public bool OffersInPerson { get; set; }
}