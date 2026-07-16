namespace MindBloom.Application.Features.Admin.DTOs;

public class TherapistVerificationListDto
{
    public int TherapistId { get; set; }

    public int UserId { get; set; }

    public string FullName { get; set; }
        = string.Empty;

    public string Email { get; set; }
        = string.Empty;

    public string Specialization { get; set; }
        = string.Empty;

    public int ExperienceYears { get; set; }

    public string VerificationStatus { get; set; }
        = string.Empty;

    public string? ProfileImageUrl { get; set; }

    public int DocumentCount { get; set; }

    public DateTime RegisteredAtUtc { get; set; }
}