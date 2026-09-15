using System.ComponentModel.DataAnnotations;

namespace MindBloom.Application.Features.Admin.DTOs;

public class UpdateAdminUserDto
{
    [Required]
    [MaxLength(100)]
    public string FirstName { get; set; } = string.Empty;

    [Required]
    [MaxLength(100)]
    public string LastName { get; set; } = string.Empty;

    [Phone]
    public string? PhoneNumber { get; set; }

    [Required]
    public DateTime DateOfBirth { get; set; }

    [MaxLength(30)]
    public string? Gender { get; set; }
}