using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public sealed class UserConsent : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; }
        = null!;

    public UserConsentType ConsentType
    {
        get;
        set;
    }

    public string DocumentVersion { get; set; }
        = string.Empty;

    public bool IsAccepted { get; set; }

    public DateTime AcceptedAtUtc { get; set; }
}