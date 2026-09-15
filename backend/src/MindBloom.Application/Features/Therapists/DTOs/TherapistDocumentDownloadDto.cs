namespace MindBloom.Application.Features.Therapists.DTOs;

public sealed class TherapistDocumentDownloadDto
{
    public byte[] Content { get; set; } =
        Array.Empty<byte>();

    public string FileName { get; set; } =
        string.Empty;

    public string ContentType { get; set; } =
        "application/octet-stream";
}