namespace MindBloom.Domain.Entities;

public class EmailVerificationCode : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public string CodeHash { get; set; } = string.Empty;

    public DateTime ExpiresAtUtc { get; set; }

    public bool IsUsed { get; set; }
}