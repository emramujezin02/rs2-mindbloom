namespace MindBloom.Application.Features.Therapists.DTOs;

public sealed class TherapistClientProfileDto
{
    public int ClientId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? PhoneNumber { get; set; }
}
