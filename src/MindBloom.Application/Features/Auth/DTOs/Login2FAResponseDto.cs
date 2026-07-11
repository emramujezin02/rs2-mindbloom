namespace MindBloom.Application.Features.Auth.DTOs;

public class Login2FAResponseDto
{
    public bool RequiresTwoFactor { get; set; }

    public string Message { get; set; } = string.Empty;

    public AuthResponseDto? Auth { get; set; }
}