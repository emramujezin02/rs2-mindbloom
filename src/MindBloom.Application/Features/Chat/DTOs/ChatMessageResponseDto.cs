namespace MindBloom.Application.Features.Chat.DTOs;

public class ChatMessageResponseDto
{
    public int Id { get; set; }

    public int ConversationId { get; set; }

    public int SenderUserId { get; set; }

    public string SenderName { get; set; }
        = string.Empty;

    public string Content { get; set; }
        = string.Empty;

    public DateTime SentAtUtc { get; set; }

    public bool IsMine { get; set; }

    public bool IsEdited { get; set; }
}