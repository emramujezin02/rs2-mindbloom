namespace MindBloom.Application.Features.Therapists.DTOs;

public class UnavailableDateResponseDto
{
    public int Id { get; set; }

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Reason { get; set; } = string.Empty;
}