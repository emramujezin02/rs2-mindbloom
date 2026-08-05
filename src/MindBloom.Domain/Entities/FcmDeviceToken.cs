namespace MindBloom.Domain.Entities;

public sealed class FcmDeviceToken
    : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } =
        null!;

    public string Token { get; set; } =
        string.Empty;

    public string Platform { get; set; } =
        string.Empty;

    public string? DeviceId { get; set; }

    public bool IsActive { get; set; } =
        true;

    public DateTime RegisteredAtUtc { get; set; } =
        DateTime.UtcNow;

    public DateTime? LastUsedAtUtc { get; set; }

    public DateTime? InvalidatedAtUtc { get; set; }
}