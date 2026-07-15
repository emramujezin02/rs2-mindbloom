namespace MindBloom.Application.Features.Chat.DTOs;

public class ConversationResponseDto
{
    public int Id { get; set; }

    public int AppointmentId { get; set; }

    public string OtherParticipantName { get; set; }
        = string.Empty;

    public bool IsClosed { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}