using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Enums;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.Infrastructure.Services;

public sealed class BusinessNotificationService
    : IBusinessNotificationService
{
    private readonly IIntegrationEventPublisher
        _integrationEventPublisher;

    public BusinessNotificationService(
        IIntegrationEventPublisher
            integrationEventPublisher)
    {
        _integrationEventPublisher =
            integrationEventPublisher;
    }

    public Task PublishAsync(
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
            title?.Trim()
            ?? string.Empty;

        var normalizedMessage =
            message?.Trim()
            ?? string.Empty;

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
                NotificationActionType
                    .Appointment;
        }

        var resolvedCorrelationId =
            correlationId.HasValue &&
            correlationId.Value != Guid.Empty
                ? correlationId.Value
                : Guid.NewGuid();

        var notificationRequestedEvent =
            new NotificationRequestedEvent
            {
                CorrelationId =
                    resolvedCorrelationId,

                TimestampUtc =
                    DateTime.UtcNow,

                UserId =
                    userId,

                Title =
                    normalizedTitle,

                Message =
                    normalizedMessage,

                AppointmentId =
                    appointmentId,

                ActionType =
                    actionType.ToString(),

                ResourceId =
                    resourceId,

                /*
                 * API više ne kreira Notification.
                 * ID će nastati kada Worker snimi zapis.
                 */
                NotificationId =
                    null
            };

        return _integrationEventPublisher
            .PublishAsync(
                notificationRequestedEvent,
                IntegrationEventRoutingKeys
                    .NotificationRequested,
                cancellationToken);
    }
}