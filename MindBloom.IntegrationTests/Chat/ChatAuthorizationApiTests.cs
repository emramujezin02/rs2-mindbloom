using System.Net;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Chat;

public sealed class ChatAuthorizationApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public ChatAuthorizationApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        Conversations_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Chat/conversations");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Conversations_WithAdminRole_ReturnsForbidden()
    {
        const int userId =
            89001;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Admin,
            "chat-admin@test.local",
            "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Admin);

        var response =
            await client.GetAsync(
                "/api/Chat/conversations");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Conversations_WithClientRole_IsAuthorized()
    {
        const int userId =
            89002;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "chat-client@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                userId);

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                "/api/Chat/conversations");

        Assert.NotEqual(
            HttpStatusCode.Unauthorized,
            response.StatusCode);

        Assert.NotEqual(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }
}