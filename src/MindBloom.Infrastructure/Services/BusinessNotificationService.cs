using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.Infrastructure.Services;

public sealed class BusinessNotificationService
    : IBusinessNotificationService
{
    private readonly ApplicationDbContext
        _context;

    private readonly INotificationSender
        _notificationSender;

    private readonly IIntegrationEventPublisher
        _integrationEventPublisher;

    public BusinessNotificationService(
        ApplicationDbContext context,
        INotificationSender notificationSender,
        IIntegrationEventPublisher
            integrationEventPublisher)
    {
        _context =
            context;

        _notificationSender =
            notificationSender;

        _integrationEventPublisher =
            integrationEventPublisher;
    }

    public async Task PublishAsync(
        int userId,
        string title,
        string message,
        int? appointmentId = null,
        NotificationActionType actionType =
            NotificationActionType.None,
        int? resourceId = null,
        Guid? correlationId = null,
        CancellationToken cancellationToken =
            default)
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

        var occurredAtUtc =
            DateTime.UtcNow;

        var resolvedCorrelationId =
            correlationId.HasValue &&
            correlationId.Value != Guid.Empty
                ? correlationId.Value
                : Guid.NewGuid();

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
                    occurredAtUtc
            };

        _context.Notifications.Add(
            notification);

        await _context.SaveChangesAsync(
            cancellationToken);

        await _notificationSender
            .SendToUserAsync(
                userId,
                normalizedTitle,
                normalizedMessage);

        var notificationRequestedEvent =
            new NotificationRequestedEvent
            {
                CorrelationId =
                    resolvedCorrelationId,

                TimestampUtc =
                    occurredAtUtc,

                UserId =
                    userId,

                NotificationId =
                    notification.Id,

                Title =
                    normalizedTitle,

                Message =
                    normalizedMessage,

                AppointmentId =
                    appointmentId,

                ActionType =
                    actionType.ToString(),

                ResourceId =
                    resourceId
            };

        await _integrationEventPublisher
            .PublishAsync(
                notificationRequestedEvent,
                IntegrationEventRoutingKeys
                    .NotificationRequested,
                cancellationToken);
    }
}