using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Workshops;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Workshops;

public sealed class WorkshopCancelledEventHandler
    : IIntegrationEventHandler<
        WorkshopCancelledEvent>
{
    private readonly ApplicationDbContext
        _context;

    private readonly WorkerNotificationService
        _notificationService;

    public WorkshopCancelledEventHandler(
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
        WorkshopCancelledEvent integrationEvent,
        CancellationToken cancellationToken)
    {
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

        var reason =
            string.IsNullOrWhiteSpace(
                integrationEvent.Reason)
                ? string.Empty
                : $" Reason: "
                  + integrationEvent
                      .Reason
                      .Trim();

        var message =
            $"Workshop \"{integrationEvent.Title}\" "
            + "has been cancelled."
            + reason;

        foreach (var userId
                 in registeredUserIds)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            await _notificationService
                .NotifyAsync(
                    userId,
                    "Workshop cancelled",
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