namespace MindBloom.Application.Features.Notifications.DTOs;

public sealed class NotificationPageResponseDto
{
    public List<NotificationResponseDto> Items
    {
        get;
        set;
    } = [];

    public int PageNumber { get; set; }

    public int PageSize { get; set; }

    public int TotalCount { get; set; }

    public int TotalPages { get; set; }

    public int UnreadCount { get; set; }
}