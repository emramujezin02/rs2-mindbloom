using MindBloom.Application.Features.Notifications.DTOs;

namespace MindBloom.Application.Features.Notifications.Interfaces;

public interface INotificationService
{
    Task<List<NotificationResponseDto>>
        GetMyNotificationsAsync(int userId);

    Task MarkAsReadAsync(
        int userId,
        int notificationId);
}