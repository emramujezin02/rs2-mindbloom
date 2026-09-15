using Microsoft.Extensions.Logging;
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

    private readonly ILogger<
    BusinessNotificationService>
    _logger;

    public BusinessNotificationService(
        IIntegrationEventPublisher
            integrationEventPublisher,
        ILogger<BusinessNotificationService>
            logger)
    {
        _integrationEventPublisher =
            integrationEventPublisher;

        _logger =
            logger;
    }

    public async Task PublishAsync(
        int userId,
        string title,
        string message,
        int? appointmentId = null,
        NotificationActionType actionType =
            NotificationActionType.None,
        int? resourceId = null,
        bool sendEmail = false,
        bool sendPush = true,
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

                NotificationId =
                    null,

                SendEmail = sendEmail,

                SendPush =
    sendPush,
            };

        try
        {
            await _integrationEventPublisher
                .PublishAsync(
                    notificationRequestedEvent,
                    IntegrationEventRoutingKeys
                        .NotificationRequested,
                    cancellationToken);
        }
        catch (OperationCanceledException)
            when (cancellationToken
                .IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {

            _logger.LogWarning(
                exception,
                "Business notification could not be queued. "
                + "The business operation remains successful. "
                + "Module: {Module}, "
                + "UserId: {UserId}, "
                + "AppointmentId: {AppointmentId}, "
                + "ResourceId: {ResourceId}, "
                + "ActionType: {ActionType}.",
                "BusinessNotifications",
                userId,
                appointmentId,
                resourceId,
                actionType.ToString());
        }
    }
}