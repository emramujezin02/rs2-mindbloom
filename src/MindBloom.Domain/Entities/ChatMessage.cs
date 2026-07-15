namespace MindBloom.Domain.Entities;

public class ChatMessage : BaseEntity
{
    public int ConversationId { get; set; }

    public Conversation Conversation { get; set; }
        = null!;

    public int SenderUserId { get; set; }

    public ApplicationUser SenderUser { get; set; }
        = null!;

    public string Content { get; set; }
        = string.Empty;

    public DateTime SentAtUtc { get; set; }

    public DateTime? EditedAtUtc { get; set; }

    public bool IsEdited { get; set; }
}