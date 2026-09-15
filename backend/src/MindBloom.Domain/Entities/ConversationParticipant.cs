namespace MindBloom.Domain.Entities;

public class ConversationParticipant
    : BaseEntity
{
    public int ConversationId { get; set; }

    public Conversation Conversation { get; set; }
        = null!;

    public int UserId { get; set; }

    public ApplicationUser User { get; set; }
        = null!;

    public DateTime JoinedAtUtc { get; set; }

    public DateTime? LastReadAtUtc { get; set; }

    public bool IsActive { get; set; } = true;
}