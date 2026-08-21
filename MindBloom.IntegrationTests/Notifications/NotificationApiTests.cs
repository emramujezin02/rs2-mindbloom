using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Notifications;

public sealed class NotificationApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public NotificationApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        GetNotifications_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Notifications");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        UnreadCount_ReturnsOnlyAuthenticatedUsersUnreadNotifications()
    {
        const int firstUserId =
            88001;

        const int secondUserId =
            88002;

        await _factory.SeedActiveUserAsync(
            firstUserId,
            RoleConstants.Client,
            "notification-first@test.local",
            "Password123!");

        await _factory.SeedActiveUserAsync(
            secondUserId,
            RoleConstants.Client,
            "notification-second@test.local",
            "Password123!");

        await _factory.SeedNotificationAsync(
            firstUserId,
            "Unread one");

        await _factory.SeedNotificationAsync(
            firstUserId,
            "Unread two");

        await _factory.SeedNotificationAsync(
            firstUserId,
            "Already read",
            isRead: true);

        await _factory.SeedNotificationAsync(
            secondUserId,
            "Another user's notification");

        using var client =
            _factory.CreateAuthenticatedClient(
                firstUserId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                "/api/Notifications/unread-count");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            2,
            json.GetProperty("unreadCount")
                .GetInt32());
    }

    [Fact]
    public async Task
        MarkAsRead_ChangesAuthenticatedUsersNotification()
    {
        const int userId =
            88003;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "notification-read@test.local",
            "Password123!");

        var notificationId =
            await _factory
                .SeedNotificationAsync(
                    userId,
                    "Read me");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        var response =
            await client.PutAsync(
                $"/api/Notifications/{notificationId}/read",
                null);

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            "Notification marked as read.",
            json.GetProperty("message")
                .GetString());

        var countResponse =
            await client.GetAsync(
                "/api/Notifications/unread-count");

        var countJson =
            await countResponse.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            0,
            countJson.GetProperty(
                    "unreadCount")
                .GetInt32());
    }
}