namespace MindBloom.Application.Features.Chat.DTOs;

public class ConversationListItemDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public string OtherParticipantName { get; set; }
        = string.Empty;

    public string? LastMessage { get; set; }

    public DateTime? LastMessageAtUtc { get; set; }

    public int UnreadCount { get; set; }

    public bool IsClosed { get; set; }
}