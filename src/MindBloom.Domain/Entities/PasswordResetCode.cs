namespace MindBloom.Domain.Entities;

public class PasswordResetCode : BaseEntity
{
    public string Email { get; set; } = string.Empty;

    public string Code { get; set; } = string.Empty;

    public DateTime ExpiresAtUtc { get; set; }

    public bool IsUsed { get; set; }
}