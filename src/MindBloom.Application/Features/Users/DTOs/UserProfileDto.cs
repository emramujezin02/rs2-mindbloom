namespace MindBloom.Application.Features.Users.DTOs;

public class UserProfileDto
{
    public string FirstName { get; set; } =
        string.Empty;

    public string LastName { get; set; } =
        string.Empty;

    public string Email { get; set; } =
        string.Empty;

    public string PhoneNumber { get; set; } =
        string.Empty;

    public DateTime DateOfBirth { get; set; }

    public string? ProfileImageUrl { get; set; }
}