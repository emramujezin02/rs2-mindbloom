namespace MindBloom.Domain.Entities;

public class Conversation : BaseEntity
{
    public int AppointmentId { get; set; }

    public Appointment Appointment { get; set; } = null!;

    public bool IsClosed { get; set; }

    public DateTime? ClosedAtUtc { get; set; }

    public ICollection<ConversationParticipant>
        Participants
    { get; set; }
            = new List<ConversationParticipant>();

    public ICollection<ChatMessage>
        Messages
    { get; set; }
            = new List<ChatMessage>();
}