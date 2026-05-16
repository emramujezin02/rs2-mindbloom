namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistDocumentResponseDto
{
    public int Id { get; set; }

    public string FileName { get; set; }
        = string.Empty;

    public string FilePath { get; set; }
        = string.Empty;

    public string ContentType { get; set; }
        = string.Empty;

    public bool IsApproved { get; set; }
}