using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class TherapistVerificationAudit
    : BaseEntity
{
    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; }
        = null!;

    public int AdminUserId { get; set; }

    public ApplicationUser AdminUser { get; set; }
        = null!;

    public TherapistVerificationStatus
        PreviousStatus
    { get; set; }

    public TherapistVerificationStatus
        NewStatus
    { get; set; }

    public string? Notes { get; set; }

    public DateTime ChangedAtUtc { get; set; }
}