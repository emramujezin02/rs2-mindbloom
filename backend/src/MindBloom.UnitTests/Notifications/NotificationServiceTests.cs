using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Notifications;

public sealed class NotificationServiceTests
{
    [Fact]
    public async Task
        GetUnreadCountAsync_ReturnsOnlyUnreadNotificationsForUser()
    {
        await using var context =
            CreateContext();

        context.Notifications.AddRange(
            CreateNotification(
                1,
                false),

            CreateNotification(
                1,
                true),

            CreateNotification(
                2,
                false));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var result =
            await service
                .GetUnreadCountAsync(
                    1);

        Assert.Equal(
            1,
            result);
    }

    [Fact]
    public async Task
        GetMyNotificationsAsync_WhenReadFilterSpecified_ReturnsMatchingItems()
    {
        await using var context =
            CreateContext();

        context.Notifications.AddRange(
            CreateNotification(
                1,
                false),

            CreateNotification(
                1,
                true));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var result =
            await service
                .GetMyNotificationsAsync(
                    1,
                    new NotificationQueryDto
                    {
                        PageNumber =
                            1,

                        PageSize =
                            20,

                        IsRead =
                            false
                    });

        var item =
            Assert.Single(
                result.Items);

        Assert.False(
            item.IsRead);

        Assert.Equal(
            1,
            result.UnreadCount);
    }

    [Fact]
    public async Task
        MarkAsReadAsync_WhenNotificationDoesNotBelongToUser_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var notification =
            CreateNotification(
                2,
                false);

        context.Notifications.Add(
            notification);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.MarkAsReadAsync(
                    1,
                    notification.Id));
    }

    [Fact]
    public async Task
        MarkAsReadAsync_WithUnreadNotification_MarksNotificationAsRead()
    {
        await using var context =
            CreateContext();

        var notification =
            CreateNotification(
                1,
                false);

        context.Notifications.Add(
            notification);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service.MarkAsReadAsync(
            1,
            notification.Id);

        Assert.True(
            notification.IsRead);
    }

    [Fact]
    public async Task
        MarkAsReadAsync_WhenAlreadyRead_RemainsRead()
    {
        await using var context =
            CreateContext();

        var notification =
            CreateNotification(
                1,
                true);

        context.Notifications.Add(
            notification);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service.MarkAsReadAsync(
            1,
            notification.Id);

        Assert.True(
            notification.IsRead);
    }

    [Fact]
    public async Task
        MarkAllAsReadAsync_MarksAllUsersUnreadNotifications()
    {
        await using var context =
            CreateContext();

        context.Notifications.AddRange(
            CreateNotification(
                1,
                false),

            CreateNotification(
                1,
                false),

            CreateNotification(
                2,
                false));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service
            .MarkAllAsReadAsync(
                1);

        var userOneUnread =
            await context.Notifications
                .CountAsync(x =>
                    x.UserId == 1 &&
                    !x.IsRead);

        var userTwoUnread =
            await context.Notifications
                .CountAsync(x =>
                    x.UserId == 2 &&
                    !x.IsRead);

        Assert.Equal(
            0,
            userOneUnread);

        Assert.Equal(
            1,
            userTwoUnread);
    }

    private static NotificationService
        CreateService(
            ApplicationDbContext context)
    {
        var logger =
            new Mock<
                ILogger<NotificationService>>();

        return new NotificationService(
            context,
            logger.Object);
    }

    private static Notification
        CreateNotification(
            int userId,
            bool isRead)
    {
        return new Notification
        {
            UserId =
                userId,

            Title =
                "Unit test notification",

            Message =
                "Unit test message",

            IsRead =
                isRead,

            ActionType =
                NotificationActionType.None,

            SentAtUtc =
                DateTime.UtcNow,

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"notification-unit-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }
}