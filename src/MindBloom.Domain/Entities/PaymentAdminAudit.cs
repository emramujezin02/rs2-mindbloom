using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class PaymentAdminAudit : BaseEntity
{
    public int AdminUserId { get; set; }

    public ApplicationUser AdminUser { get; set; }
        = null!;

    public string PaymentType { get; set; }
        = string.Empty;

    public int PaymentId { get; set; }

    public PaymentStatus PreviousStatus { get; set; }

    public PaymentStatus NewStatus { get; set; }

    public string Action { get; set; }
        = string.Empty;

    public string Reason { get; set; }
        = string.Empty;

    public DateTime PerformedAtUtc { get; set; }
}