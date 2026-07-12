namespace MindBloom.Application.Features.Users.DTOs;

public class UpdateUserProfileDto
{
    public string FirstName { get; set; } =
        string.Empty;

    public string LastName { get; set; } =
        string.Empty;

    public string? PhoneNumber { get; set; }
}