using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Workshops;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Workshops;

public sealed class WorkshopUpdatedEventHandler
    : IIntegrationEventHandler<
        WorkshopUpdatedEvent>
{
    private readonly ApplicationDbContext
        _context;

    private readonly WorkerNotificationService
        _notificationService;

    public WorkshopUpdatedEventHandler(
        ApplicationDbContext context,
        WorkerNotificationService
            notificationService)
    {
        _context =
            context;

        _notificationService =
            notificationService;
    }

    public async Task HandleAsync(
        WorkshopUpdatedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        if (!integrationEvent.ScheduleChanged &&
            !integrationEvent.LocationChanged)
        {
            return;
        }

        var registeredUserIds =
            await _context
                .WorkshopRegistrations
                .AsNoTracking()
                .Where(registration =>
                    registration.WorkshopId ==
                        integrationEvent.WorkshopId &&
                    !registration.IsDeleted)
                .Select(registration =>
                    registration.Client.UserId)
                .Distinct()
                .ToListAsync(
                    cancellationToken);

        if (registeredUserIds.Count == 0)
        {
            return;
        }

        var changes =
            new List<string>();

        if (integrationEvent.ScheduleChanged)
        {
            changes.Add(
                "the workshop schedule has changed");
        }

        if (integrationEvent.LocationChanged)
        {
            changes.Add(
                "the workshop location has changed");
        }

        var changesText =
            string.Join(
                " and ",
                changes);

        var startDate =
            integrationEvent
                .StartUtc
                .ToString(
                    "dd.MM.yyyy. HH:mm");

        var message =
            $"Workshop \"{integrationEvent.Title}\" was updated: "
            + $"{changesText}. "
            + $"Current start time: {startDate} UTC.";

        foreach (var userId
                 in registeredUserIds)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            await _notificationService
                .NotifyAsync(
                    userId,
                    "Workshop updated",
                    message,
                    NotificationActionType
                        .Workshop,
                    resourceId:
                        integrationEvent
                            .WorkshopId,
                    cancellationToken:
                        cancellationToken);
        }
    }
}