namespace MindBloom.Application.Features.Chat.DTOs;

public class SendChatMessageDto
{
    public int ConversationId { get; set; }

    public string Content { get; set; }
        = string.Empty;

    public string ClientMessageId { get; set; }
        = string.Empty;
}