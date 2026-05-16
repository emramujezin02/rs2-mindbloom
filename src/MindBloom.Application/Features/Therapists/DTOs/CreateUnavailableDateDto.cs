namespace MindBloom.Application.Features.Therapists.DTOs;

public class CreateUnavailableDateDto
{
    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Reason { get; set; } = string.Empty;
}