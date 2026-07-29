namespace MindBloom.Domain.Entities;

public class UserSettings : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public bool NotificationsEnabled { get; set; } = true;

    public bool ShowProfilePublicly { get; set; } = true;
}