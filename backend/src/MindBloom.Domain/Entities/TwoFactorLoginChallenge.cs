namespace MindBloom.Domain.Entities;

public sealed class TwoFactorLoginChallenge
    : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; }
        = null!;

    public string ChallengeHash { get; set; }
        = string.Empty;

    public string CodeHash { get; set; }
        = string.Empty;

    public DateTime IssuedAtUtc { get; set; }

    public DateTime ExpiresAtUtc { get; set; }

    public int FailedAttempts { get; set; }

    public int MaximumAttempts { get; set; } = 5;

    public bool IsUsed { get; set; }

    public DateTime? UsedAtUtc { get; set; }

    public DateTime? LockedAtUtc { get; set; }

    public bool RememberMe { get; set; }
}