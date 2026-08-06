namespace MindBloom.Application.Features.Auth.DTOs;

public sealed class RegisterTherapistResponseDto
{
    public int UserId { get; set; }

    public int TherapistId { get; set; }

    public string Email { get; set; } =
        string.Empty;

    public string VerificationStatus { get; set; } =
        string.Empty;

    public string Message { get; set; } =
        string.Empty;
}