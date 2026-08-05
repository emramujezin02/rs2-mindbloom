using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Notifications;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker
    .Handlers.Notifications;

public sealed class NotificationRequestedEventHandler
    : IIntegrationEventHandler<
        NotificationRequestedEvent>
{
    private readonly ApplicationDbContext
        _context;

    private readonly WorkerNotificationService
        _notificationService;

    private readonly ILogger<
        NotificationRequestedEventHandler>
        _logger;

    public NotificationRequestedEventHandler(
        ApplicationDbContext context,
        WorkerNotificationService
            notificationService,
        ILogger<
            NotificationRequestedEventHandler>
            logger)
    {
        _context =
            context;

        _notificationService =
            notificationService;

        _logger =
            logger;
    }

    public async Task HandleAsync(
        NotificationRequestedEvent
            integrationEvent,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(
            integrationEvent);

        if (integrationEvent.UserId <= 0)
        {
            throw new ArgumentException(
                "Notification user identifier is invalid.");
        }

        if (string.IsNullOrWhiteSpace(
                integrationEvent.Title))
        {
            throw new ArgumentException(
                "Notification title is required.");
        }

        if (string.IsNullOrWhiteSpace(
                integrationEvent.Message))
        {
            throw new ArgumentException(
                "Notification message is required.");
        }

        /*
         * Transitional protection.
         *
         * Ako event dolazi iz starog toka u kojem
         * je API već napravio Notification zapis,
         * ne pravimo drugi isti zapis.
         *
         * Novi tok treba imati NotificationId = null
         * jer Notification kreira Worker.
         */
        if (integrationEvent
                .NotificationId
                .HasValue)
        {
            var alreadyExists =
                await _context.Notifications
                    .AsNoTracking()
                    .AnyAsync(
                        notification =>
                            notification.Id ==
                            integrationEvent
                                .NotificationId
                                .Value &&
                            notification.UserId ==
                            integrationEvent.UserId &&
                            !notification.IsDeleted,
                        cancellationToken);

            if (alreadyExists)
            {
                _logger.LogInformation(
                    "Notification request {EventId} skipped because notification {NotificationId} already exists.",
                    integrationEvent.EventId,
                    integrationEvent
                        .NotificationId);

                return;
            }
        }

        var actionType =
            ParseActionType(
                integrationEvent.ActionType);

        await _notificationService
            .NotifyAsync(
                integrationEvent.UserId,
                integrationEvent.Title.Trim(),
                integrationEvent.Message.Trim(),
                actionType,
                appointmentId:
                    integrationEvent
                        .AppointmentId,
                resourceId:
                    integrationEvent
                        .ResourceId,
                sendEmail:
                    false,
                cancellationToken:
                    cancellationToken);

        _logger.LogInformation(
            "Notification request processed by worker. "
            + "User ID: {UserId}, "
            + "event ID: {EventId}, "
            + "correlation ID: {CorrelationId}.",
            integrationEvent.UserId,
            integrationEvent.EventId,
            integrationEvent.CorrelationId);
    }

    private static NotificationActionType
        ParseActionType(
            string? actionType)
    {
        if (string.IsNullOrWhiteSpace(
                actionType))
        {
            return NotificationActionType.None;
        }

        return Enum.TryParse<
                NotificationActionType>(
                actionType.Trim(),
                ignoreCase: true,
                out var parsed)
            ? parsed
            : NotificationActionType.None;
    }
}