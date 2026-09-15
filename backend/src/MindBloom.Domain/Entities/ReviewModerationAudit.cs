using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class ReviewModerationAudit : BaseEntity
{
    public int ReviewId { get; set; }

    public Review Review { get; set; } = null!;

    public int AdminUserId { get; set; }

    public ApplicationUser AdminUser { get; set; } = null!;

    public ReviewModerationAction Action { get; set; }

    public string Reason { get; set; } = string.Empty;

    public DateTime PerformedAtUtc { get; set; }
}