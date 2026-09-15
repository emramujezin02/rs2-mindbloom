namespace MindBloom.Application.Features.Notifications.DTOs;

public sealed class NotificationResponseDto
{
    public int Id { get; set; }

    public string Title { get; set; }
        = string.Empty;

    public string Message { get; set; }
        = string.Empty;

    public bool IsRead { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public string ActionType { get; set; }
        = "None";

    public int? AppointmentId { get; set; }

    public int? ResourceId { get; set; }

    public bool IsActionAvailable { get; set; }

    public string? UnavailableReason { get; set; }
}