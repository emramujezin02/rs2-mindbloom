namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminUserDetailsDto
{
    public int Id { get; set; }

    public string FirstName { get; set; } =
        string.Empty;

    public string LastName { get; set; } =
        string.Empty;

    public string FullName { get; set; } =
        string.Empty;

    public string Email { get; set; } =
        string.Empty;

    public string? PhoneNumber { get; set; }

    public DateTime DateOfBirth { get; set; }

    public string Gender { get; set; } =
        string.Empty;

    public string Role { get; set; } =
        string.Empty;

    public string? ProfileImageUrl { get; set; }

    public bool IsActive { get; set; }

    public bool IsBlocked { get; set; }

    public bool IsEmailVerified { get; set; }

    public bool IsTwoFactorEnabled { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? LastLoginAtUtc { get; set; }
    public List<AdminUserAuditDto> AuditHistory { get; set; }
    = new();
}