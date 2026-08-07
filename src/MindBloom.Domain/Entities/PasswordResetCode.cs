namespace MindBloom.Domain.Entities;

public class PasswordResetCode : BaseEntity
{
    public string Email { get; set; } =
        string.Empty;

    public string TokenHash { get; set; } =
        string.Empty;

    public DateTime ExpiresAtUtc { get; set; }

    public bool IsUsed { get; set; }

    public DateTime? UsedAtUtc { get; set; }
}