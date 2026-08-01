using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class Workshop : BaseEntity
{
    public string Title { get; set; } =
        string.Empty;

    public string Description { get; set; } =
        string.Empty;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public WorkshopType Type { get; set; }

    public string? OnlineLink { get; set; }

    public string? Location { get; set; }

    public int Capacity { get; set; }

    public decimal Price { get; set; }

    public WorkshopStatus Status { get; set; } =
        WorkshopStatus.Scheduled;

    public int OrganizerUserId { get; set; }

    public ApplicationUser OrganizerUser { get; set; } =
        null!;

    public string? ImageUrl { get; set; }

    public DateTime RegistrationDeadlineUtc { get; set; }

    public int? TherapistId { get; set; }

    public Therapist? Therapist { get; set; }

    public int? StatusChangedByUserId { get; set; }

    public ApplicationUser? StatusChangedByUser { get; set; }

    public DateTime? StatusChangedAtUtc { get; set; }

    public string? StatusChangeReason { get; set; }

    public ICollection<WorkshopRegistration>
        Registrations
    { get; set; } =
        new List<WorkshopRegistration>();
}