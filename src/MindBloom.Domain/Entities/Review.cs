namespace MindBloom.Domain.Entities;

public class Review : BaseEntity
{
    public int ClientId { get; set; }

    public Client Client { get; set; } = null!;

    public int TherapistId { get; set; }

    public Therapist Therapist { get; set; } = null!;

    public int AppointmentId { get; set; }

    public Appointment Appointment { get; set; } =
        null!;

    public int Rating { get; set; }

    public string Comment { get; set; } =
        string.Empty;

    public string? TherapistReply { get; set; }

    public DateTime?
        TherapistReplyCreatedAtUtc
    { get; set; }
}