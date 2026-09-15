using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class Notification : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; }
        = null!;

    public int? AppointmentId { get; set; }

    public Appointment? Appointment { get; set; }

    public NotificationActionType ActionType
    {
        get;
        set;
    } = NotificationActionType.None;

    public int? ResourceId { get; set; }

    public string Title { get; set; }
        = string.Empty;

    public string Message { get; set; }
        = string.Empty;

    public bool IsRead { get; set; }

    public DateTime SentAtUtc { get; set; }
}