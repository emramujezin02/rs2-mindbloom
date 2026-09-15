namespace MindBloom.Domain.Entities;

public class RefreshToken : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; }
        = null!;

    public string TokenHash { get; set; }
        = string.Empty;

    public DateTime IssuedAtUtc { get; set; }

    public DateTime ExpiresAtUtc { get; set; }

    public DateTime? RevokedAtUtc { get; set; }

    public string? ReplacedByTokenHash
    {
        get;
        set;
    }

    public string SessionId { get; set; }
        = string.Empty;

    public bool IsRevoked =>
        RevokedAtUtc.HasValue;
}