namespace MindBloom.Application.Features.Auth.DTOs;

public class LoginResponseDto
{
    public string Token { get; set; } = string.Empty;

    public DateTime ExpiresAtUtc { get; set; }
}