namespace MindBloom.Application.Features.Privacy.DTOs;

public sealed class UserConsentDto
{
    public string ConsentType { get; set; }
        = string.Empty;

    public string DocumentVersion { get; set; }
        = string.Empty;

    public bool IsAccepted { get; set; }

    public DateTime AcceptedAtUtc { get; set; }
}