using Microsoft.EntityFrameworkCore;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Messaging.Contracts.Articles;
using MindBloom.NotificationsWorker.Services;

namespace MindBloom.NotificationsWorker.Handlers.Articles;

public sealed class ArticlePublishedEventHandler
    : IIntegrationEventHandler<
        ArticlePublishedEvent>
{
    private readonly ApplicationDbContext
        _context;

    private readonly WorkerNotificationService
        _notificationService;

    public ArticlePublishedEventHandler(
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
        ArticlePublishedEvent integrationEvent,
        CancellationToken cancellationToken)
    {
        var userIds =
            await _context.Users
                .AsNoTracking()
                .Where(user =>
                    user.IsActive &&
                    !user.IsBlocked)
                .Select(user =>
                    user.Id)
                .ToListAsync(
                    cancellationToken);

        if (userIds.Count == 0)
        {
            return;
        }

        var message =
            $"A new article \"{integrationEvent.Title}\" "
            + $"has been published in "
            + $"{integrationEvent.CategoryName}.";

        foreach (var userId
                 in userIds)
        {
            cancellationToken
                .ThrowIfCancellationRequested();

            await _notificationService
                .NotifyAsync(
                    userId,
                    "New article published",
                    message,
                    NotificationActionType.None,
                    resourceId:
                        integrationEvent
                            .ArticleId,
                    sendEmail:
                        false,
                    cancellationToken:
                        cancellationToken);
        }
    }
}