namespace MindBloom.Application.Features.Admin.DTOs;

public class TherapistVerificationDetailsDto
{
    public int TherapistId { get; set; }

    public int UserId { get; set; }

    public string FullName { get; set; }
        = string.Empty;

    public string Email { get; set; }
        = string.Empty;

    public string? PhoneNumber { get; set; }

    public DateTime DateOfBirth { get; set; }

    public string Biography { get; set; }
        = string.Empty;

    public string Specialization { get; set; }
        = string.Empty;

    public decimal HourlyRate { get; set; }

    public int ExperienceYears { get; set; }

    public string VerificationStatus { get; set; }
        = string.Empty;

    public string? VerificationNotes { get; set; }

    public string? ProfileImageUrl { get; set; }

    public DateTime RegisteredAtUtc { get; set; }

    public List<TherapistVerificationDocumentDto>
        Documents
    { get; set; } = new();

    public List<TherapistVerificationAuditDto>
        AuditHistory
    { get; set; } = new();
}