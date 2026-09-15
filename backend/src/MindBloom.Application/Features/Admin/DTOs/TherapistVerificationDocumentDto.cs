namespace MindBloom.Application.Features.Admin.DTOs;

public class TherapistVerificationDocumentDto
{
    public int Id { get; set; }

    public string FileName { get; set; }
        = string.Empty;

    public string FilePath { get; set; }
        = string.Empty;

    public string ContentType { get; set; }
        = string.Empty;

    public bool IsApproved { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}