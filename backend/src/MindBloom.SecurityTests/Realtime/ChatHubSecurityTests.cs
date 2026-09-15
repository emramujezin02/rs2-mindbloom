using System.Net;
using MindBloom.SecurityTests.Infrastructure;
using Xunit;

namespace MindBloom.SecurityTests.Realtime;

public sealed class ChatHubSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public ChatHubSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        ChatHubNegotiate_WithoutToken_Returns401()
    {
        using var client =
            _factory.CreateClient();

        using var request =
            new HttpRequestMessage(
                HttpMethod.Post,
                "/hubs/chat/negotiate?negotiateVersion=1");

        var response =
            await client.SendAsync(
                request);

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ChatHub_WithMalformedBearerToken_Returns401()
    {
        using var client =
            _factory.CreateClient();

        using var request =
            new HttpRequestMessage(
                HttpMethod.Post,
                "/hubs/chat/negotiate?negotiateVersion=1");

        request.Headers.Authorization =
            new System.Net.Http.Headers
                .AuthenticationHeaderValue(
                    "Bearer",
                    "this-is-not-a-valid-jwt");

        var response =
            await client.SendAsync(
                request);

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ChatHub_WithExpiredToken_Returns401()
    {
        const int userId =
            98001;

        await _factory
            .SeedActiveUserAsync(
                userId,
                MindBloom.Shared.Constants
                    .RoleConstants.Client);

        var token =
            TestJwtTokenFactory
                .CreateExpiredToken(
                    userId,
                    MindBloom.Shared.Constants
                        .RoleConstants.Client);

        using var client =
            _factory.CreateClient();

        using var request =
            new HttpRequestMessage(
                HttpMethod.Post,
                "/hubs/chat/negotiate?negotiateVersion=1");

        request.Headers.Authorization =
            new System.Net.Http.Headers
                .AuthenticationHeaderValue(
                    "Bearer",
                    token);

        var response =
            await client.SendAsync(
                request);

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }
}