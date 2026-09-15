using System.Net;
using System.Net.Http.Headers;
using MindBloom.SecurityTests.Infrastructure;
using MindBloom.Shared.Constants;
using Xunit;

namespace MindBloom.SecurityTests.Authentication;

public sealed class JwtSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public JwtSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        ProtectedEndpoint_WithExpiredJwt_Returns401()
    {
        const int userId =
            92001;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        var token =
            TestJwtTokenFactory
                .CreateExpiredToken(
                    userId,
                    RoleConstants.Client);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                token);

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ProtectedEndpoint_WithInvalidJwtSignature_Returns401()
    {
        const int userId =
            92002;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        var token =
            TestJwtTokenFactory
                .CreateTokenWithInvalidSignature(
                    userId,
                    RoleConstants.Client);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                token);

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ProtectedEndpoint_WithMalformedJwt_Returns401()
    {
        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                "this-is-not-a-valid-jwt-token");

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ProtectedEndpoint_WithBlockedUserToken_Returns401()
    {
        const int userId =
            92003;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        var token =
            TestJwtTokenFactory
                .CreateValidToken(
                    userId,
                    RoleConstants.Client);

        await _factory
            .SetUserSecurityStateAsync(
                userId,
                isActive: true,
                isBlocked: true);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                token);

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ProtectedEndpoint_WithDeactivatedUserToken_Returns401()
    {
        const int userId =
            92004;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        var token =
            TestJwtTokenFactory
                .CreateValidToken(
                    userId,
                    RoleConstants.Client);

        await _factory
            .SetUserSecurityStateAsync(
                userId,
                isActive: false,
                isBlocked: false);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                token);

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ProtectedEndpoint_WithJwtForMissingUser_Returns401()
    {
        const int missingUserId =
            92999;

        var token =
            TestJwtTokenFactory
                .CreateValidToken(
                    missingUserId,
                    RoleConstants.Client);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                token);

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }
}