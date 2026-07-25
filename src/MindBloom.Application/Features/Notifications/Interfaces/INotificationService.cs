using MindBloom.Application.Features.Notifications.DTOs;

namespace MindBloom.Application.Features.Notifications.Interfaces;

public interface INotificationService
{
    Task<NotificationPageResponseDto>
        GetMyNotificationsAsync(
            int userId,
            NotificationQueryDto query);

    Task<int> GetUnreadCountAsync(
        int userId);

    Task MarkAsReadAsync(
        int userId,
        int notificationId);

    Task MarkAllAsReadAsync(
        int userId);
}