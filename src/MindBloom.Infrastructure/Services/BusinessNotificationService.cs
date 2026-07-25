using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;

namespace MindBloom.Infrastructure.Services;

public sealed class BusinessNotificationService
    : IBusinessNotificationService
{
    private readonly ApplicationDbContext
        _context;

    private readonly INotificationSender
        _notificationSender;

    public BusinessNotificationService(
        ApplicationDbContext context,
        INotificationSender notificationSender)
    {
        _context = context;

        _notificationSender =
            notificationSender;
    }

    public async Task PublishAsync(
        int userId,
        string title,
        string message,
        int? appointmentId = null,
        NotificationActionType actionType =
            NotificationActionType.None,
        int? resourceId = null)
    {
        if (userId <= 0)
        {
            throw new ArgumentException(
                "Notification user identifier is invalid.",
                nameof(userId));
        }

        var normalizedTitle =
            title?.Trim() ??
            string.Empty;

        var normalizedMessage =
            message?.Trim() ??
            string.Empty;

        if (string.IsNullOrWhiteSpace(
                normalizedTitle))
        {
            throw new ArgumentException(
                "Notification title is required.",
                nameof(title));
        }

        if (string.IsNullOrWhiteSpace(
                normalizedMessage))
        {
            throw new ArgumentException(
                "Notification message is required.",
                nameof(message));
        }

        if (actionType ==
                NotificationActionType.None &&
            appointmentId.HasValue)
        {
            actionType =
                NotificationActionType.Appointment;
        }

        var notification =
            new Notification
            {
                UserId =
                    userId,

                AppointmentId =
                    appointmentId,

                ActionType =
                    actionType,

                ResourceId =
                    resourceId,

                Title =
                    normalizedTitle,

                Message =
                    normalizedMessage,

                IsRead =
                    false,

                SentAtUtc =
                    DateTime.UtcNow
            };

        _context.Notifications.Add(
            notification);

        await _context.SaveChangesAsync();

        await _notificationSender
            .SendToUserAsync(
                userId,
                normalizedTitle,
                normalizedMessage);
    }
}