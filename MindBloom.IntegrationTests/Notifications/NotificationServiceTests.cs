using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Notifications.DTOs;
using MindBloom.Application.Features.Notifications.Interfaces;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;

namespace MindBloom.IntegrationTests.Notifications;

public sealed class NotificationServiceTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public NotificationServiceTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        GetMyNotifications_ReturnsOnlyCurrentUsersNotifications()
    {
        const int firstUserId =
            172001;

        const int secondUserId =
            172002;

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "First notification");

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "Second notification");

        await _factory
            .SeedNotificationAsync(
                secondUserId,
                "Other user notification");

        using var scope =
            _factory.Services
                .CreateScope();

        var service =
            scope.ServiceProvider
                .GetRequiredService<
                    INotificationService>();

        var result =
            await service
                .GetMyNotificationsAsync(
                    firstUserId,
                    new NotificationQueryDto
                    {
                        PageNumber =
                            1,

                        PageSize =
                            10
                    });

        Assert.Equal(
            2,
            result.TotalCount);

        Assert.Equal(
            2,
            result.Items.Count);

        Assert.DoesNotContain(
            result.Items,
            item =>
                item.Title ==
                "Other user notification");

        Assert.Contains(
            result.Items,
            item =>
                item.Title ==
                "First notification");

        Assert.Contains(
            result.Items,
            item =>
                item.Title ==
                "Second notification");
    }

    [Fact]
    public async Task
        GetMyNotifications_FiltersByUnreadStatus()
    {
        const int userId =
            172003;

        await _factory
            .SeedNotificationAsync(
                userId,
                "Unread one",
                isRead:
                    false);

        await _factory
            .SeedNotificationAsync(
                userId,
                "Unread two",
                isRead:
                    false);

        await _factory
            .SeedNotificationAsync(
                userId,
                "Already read",
                isRead:
                    true);

        using var scope =
            _factory.Services
                .CreateScope();

        var service =
            scope.ServiceProvider
                .GetRequiredService<
                    INotificationService>();

        var result =
            await service
                .GetMyNotificationsAsync(
                    userId,
                    new NotificationQueryDto
                    {
                        PageNumber =
                            1,

                        PageSize =
                            10,

                        IsRead =
                            false
                    });

        Assert.Equal(
            2,
            result.TotalCount);

        Assert.Equal(
            2,
            result.Items.Count);

        Assert.All(
            result.Items,
            item =>
                Assert.False(
                    item.IsRead));

        /*
         * UnreadCount predstavlja ukupan broj
         * nepročitanih notifikacija korisnika.
         */
        Assert.Equal(
            2,
            result.UnreadCount);
    }

    [Fact]
    public async Task
        GetMyNotifications_AppliesPagination()
    {
        const int userId =
            172004;

        for (var index = 1;
             index <= 5;
             index++)
        {
            await _factory
                .SeedNotificationAsync(
                    userId,
                    $"Pagination notification {index}");
        }

        using var scope =
            _factory.Services
                .CreateScope();

        var service =
            scope.ServiceProvider
                .GetRequiredService<
                    INotificationService>();

        var firstPage =
            await service
                .GetMyNotificationsAsync(
                    userId,
                    new NotificationQueryDto
                    {
                        PageNumber =
                            1,

                        PageSize =
                            2
                    });

        Assert.Equal(
            1,
            firstPage.PageNumber);

        Assert.Equal(
            2,
            firstPage.PageSize);

        Assert.Equal(
            5,
            firstPage.TotalCount);

        Assert.Equal(
            3,
            firstPage.TotalPages);

        Assert.Equal(
            2,
            firstPage.Items.Count);

        var secondPage =
            await service
                .GetMyNotificationsAsync(
                    userId,
                    new NotificationQueryDto
                    {
                        PageNumber =
                            2,

                        PageSize =
                            2
                    });

        Assert.Equal(
            2,
            secondPage.PageNumber);

        Assert.Equal(
            2,
            secondPage.Items.Count);

        /*
         * Stranice ne smiju vraćati iste zapise.
         */
        Assert.DoesNotContain(
            secondPage.Items,
            secondItem =>
                firstPage.Items.Any(
                    firstItem =>
                        firstItem.Id ==
                        secondItem.Id));
    }

    [Fact]
    public async Task
        GetUnreadCount_ReturnsOnlyUnreadCurrentUserNotifications()
    {
        const int firstUserId =
            172005;

        const int secondUserId =
            172006;

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "Unread A",
                isRead:
                    false);

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "Unread B",
                isRead:
                    false);

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "Read",
                isRead:
                    true);

        await _factory
            .SeedNotificationAsync(
                secondUserId,
                "Other user unread",
                isRead:
                    false);

        using var scope =
            _factory.Services
                .CreateScope();

        var service =
            scope.ServiceProvider
                .GetRequiredService<
                    INotificationService>();

        var result =
            await service
                .GetUnreadCountAsync(
                    firstUserId);

        Assert.Equal(
            2,
            result);
    }

    [Fact]
    public async Task
        MarkAsRead_MarksOnlyRequestedNotificationAsRead()
    {
        const int userId =
            172007;

        var firstId =
            await _factory
                .SeedNotificationAsync(
                    userId,
                    "Mark me as read",
                    isRead:
                        false);

        var secondId =
            await _factory
                .SeedNotificationAsync(
                    userId,
                    "Keep me unread",
                    isRead:
                        false);

        using (
            var scope =
                _factory.Services
                    .CreateScope())
        {
            var service =
                scope.ServiceProvider
                    .GetRequiredService<
                        INotificationService>();

            await service
                .MarkAsReadAsync(
                    userId,
                    firstId);
        }

        using var verificationScope =
            _factory.Services
                .CreateScope();

        var context =
            verificationScope
                .ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var first =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync(
                    item =>
                        item.Id ==
                        firstId);

        var second =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync(
                    item =>
                        item.Id ==
                        secondId);

        Assert.True(
            first.IsRead);

        Assert.False(
            second.IsRead);
    }

    [Fact]
    public async Task
        MarkAsRead_WhenNotificationBelongsToAnotherUser_ThrowsNotFound()
    {
        const int ownerUserId =
            172008;

        const int otherUserId =
            172009;

        var notificationId =
            await _factory
                .SeedNotificationAsync(
                    ownerUserId,
                    "Private notification",
                    isRead:
                        false);

        using var scope =
            _factory.Services
                .CreateScope();

        var service =
            scope.ServiceProvider
                .GetRequiredService<
                    INotificationService>();

        var exception =
            await Assert.ThrowsAsync<
                NotFoundException>(
                () =>
                    service.MarkAsReadAsync(
                        otherUserId,
                        notificationId));

        Assert.Contains(
            "Notification not found",
            exception.Message,
            StringComparison
                .OrdinalIgnoreCase);

        /*
         * Provjeravamo i da pokušaj drugog
         * korisnika nije promijenio stanje.
         */
        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        context.ChangeTracker
            .Clear();

        var notification =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync(
                    item =>
                        item.Id ==
                        notificationId);

        Assert.False(
            notification.IsRead);
    }

    [Fact]
    public async Task
        MarkAllAsRead_MarksOnlyCurrentUsersUnreadNotifications()
    {
        const int firstUserId =
            172010;

        const int secondUserId =
            172011;

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "First unread",
                isRead:
                    false);

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "Second unread",
                isRead:
                    false);

        await _factory
            .SeedNotificationAsync(
                firstUserId,
                "Already read",
                isRead:
                    true);

        var otherUserNotificationId =
            await _factory
                .SeedNotificationAsync(
                    secondUserId,
                    "Other user unread",
                    isRead:
                        false);

        using (
            var scope =
                _factory.Services
                    .CreateScope())
        {
            var service =
                scope.ServiceProvider
                    .GetRequiredService<
                        INotificationService>();

            await service
                .MarkAllAsReadAsync(
                    firstUserId);
        }

        using var verificationScope =
            _factory.Services
                .CreateScope();

        var context =
            verificationScope
                .ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var firstUserUnreadCount =
            await context.Notifications
                .AsNoTracking()
                .CountAsync(
                    item =>
                        item.UserId ==
                            firstUserId &&
                        !item.IsRead);

        Assert.Equal(
            0,
            firstUserUnreadCount);

        var otherUserNotification =
            await context.Notifications
                .AsNoTracking()
                .SingleAsync(
                    item =>
                        item.Id ==
                        otherUserNotificationId);

        Assert.False(
            otherUserNotification
                .IsRead);
    }

    [Fact]
    public async Task
        GetMyNotifications_IgnoresSoftDeletedNotifications()
    {
        const int userId =
            172012;

        await _factory
            .SeedNotificationAsync(
                userId,
                "Visible notification");

        var deletedId =
            await _factory
                .SeedNotificationAsync(
                    userId,
                    "Deleted notification");

        /*
         * Helper nema IsDeleted parametar,
         * zato testni zapis soft-deleteujemo
         * direktno kroz test DbContext.
         */
        using (
            var scope =
                _factory.Services
                    .CreateScope())
        {
            var context =
                scope.ServiceProvider
                    .GetRequiredService<
                        ApplicationDbContext>();

            var deleted =
                await context.Notifications
                    .SingleAsync(
                        item =>
                            item.Id ==
                            deletedId);

            deleted.IsDeleted =
                true;

            await context
                .SaveChangesAsync();
        }

        using var readScope =
            _factory.Services
                .CreateScope();

        var service =
            readScope.ServiceProvider
                .GetRequiredService<
                    INotificationService>();

        var result =
            await service
                .GetMyNotificationsAsync(
                    userId,
                    new NotificationQueryDto
                    {
                        PageNumber =
                            1,

                        PageSize =
                            10
                    });

        Assert.Equal(
            1,
            result.TotalCount);

        Assert.Single(
            result.Items);

        Assert.Equal(
            "Visible notification",
            result.Items[0]
                .Title);
    }
}