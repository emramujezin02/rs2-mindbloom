namespace MindBloom.Application.Features.Auth.DTOs;

public class AuthResponseDto
{
    public int Id { get; set; }

    public string FirstName { get; set; } = null!;

    public string LastName { get; set; } = null!;

    public string Email { get; set; } = null!;

    public string Token { get; set; } = null!;

    public string Role { get; set; } = null!;
}