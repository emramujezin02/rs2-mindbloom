namespace MindBloom.Application.Features.Auth.DTOs;

public class LoginResponse
{
    public string Token { get; set; } = string.Empty;

    public DateTime ExpiresAtUtc { get; set; }
}