namespace MindBloom.Domain.Entities;

public class Notification : BaseEntity
{
    public int UserId { get; set; }

    public ApplicationUser User { get; set; } = null!;

    public int? AppointmentId { get; set; }

    public Appointment? Appointment { get; set; } = null!;

    public string Title { get; set; } = null!;

    public string Message { get; set; } = null!;

    public bool IsRead { get; set; }

    public DateTime SentAtUtc { get; set; }


}