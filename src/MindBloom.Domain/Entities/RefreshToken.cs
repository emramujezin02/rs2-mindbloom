namespace MindBloom.Domain.Entities;

public class RefreshToken : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; }= null!;

    public string Token { get; set; }= string.Empty;

    public DateTime ExpiresAtUtc { get; set; }

    public bool IsRevoked { get; set; }
}