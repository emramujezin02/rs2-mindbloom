namespace MindBloom.Application.Features.Admin.DTOs;

public class UserListDto
{
    public int Id { get; set; }
    public string FirstName { get; set; } = string.Empty;
    public string LastName { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public bool IsEmailVerified { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public bool IsBlocked { get; set; }
}