namespace MindBloom.Application.Features.Therapists.DTOs;

public class UpdateTherapistProfileDto
{
    public string Biography { get; set; } = string.Empty;

    public string Specialization { get; set; } = string.Empty;

    public int ExperienceYears { get; set; }

    public decimal HourlyRate { get; set; }

    public string Location { get; set; } = string.Empty;

    public string Country { get; set; } = string.Empty;

    public string City { get; set; } = string.Empty;

    public string Address { get; set; } = string.Empty;

    public bool OffersOnline { get; set; }

    public bool OffersInPerson { get; set; }

    public List<string> Languages { get; set; } = [];

    public List<int> TherapyApproachIds { get; set; } = [];
}