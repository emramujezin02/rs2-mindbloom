using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.SecurityTests.Infrastructure;
using MindBloom.Shared.Constants;
using Xunit;

namespace MindBloom.SecurityTests.Authentication;

public sealed class RefreshTokenSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public RefreshTokenSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        RefreshToken_WhenAlreadyRevoked_Returns401()
    {
        const int userId =
            93001;

        const string rawToken =
            "revoked-refresh-token-security-test";

        const string sessionId =
            "session-revoked-token";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        await _factory
            .SeedRefreshTokenAsync(
                userId,
                rawToken,
                sessionId,
                isRevoked: true);

        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Auth/refresh-token",
                new
                {
                    refreshToken =
                        rawToken
                });

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        RefreshToken_ReusedAfterRotation_Returns401AndRevokesSession()
    {
        const int userId =
            93002;

        const string originalToken =
            "original-refresh-token-security-test";

        const string sessionId =
            "session-refresh-reuse";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        await _factory
            .SeedRefreshTokenAsync(
                userId,
                originalToken,
                sessionId);

        using var client =
            _factory.CreateClient();

        /*
         * Prvi refresh mora uspjeti.
         * Originalni token se tada opoziva,
         * a novi token pripada istom sessionu.
         */
        var firstResponse =
            await client.PostAsJsonAsync(
                "/api/Auth/refresh-token",
                new
                {
                    refreshToken =
                        originalToken
                });

        Assert.Equal(
            HttpStatusCode.OK,
            firstResponse.StatusCode);

        /*
         * Ponovna upotreba ORIGINALNOG tokena
         * mora aktivirati reuse detection.
         */
        var reuseResponse =
            await client.PostAsJsonAsync(
                "/api/Auth/refresh-token",
                new
                {
                    refreshToken =
                        originalToken
                });

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            reuseResponse.StatusCode);

        /*
         * Reuse detection mora opozvati
         * sve još aktivne tokene istog
         * session chaina.
         */
        using var scope =
            _factory.Services
                .CreateScope();

        var context =
            scope.ServiceProvider
                .GetRequiredService<
                    ApplicationDbContext>();

        var sessionTokens =
            await context.RefreshTokens
                .Where(x =>
                    x.UserId ==
                        userId &&
                    x.SessionId ==
                        sessionId)
                .ToListAsync();

        Assert.NotEmpty(
            sessionTokens);

        Assert.All(
            sessionTokens,
            token =>
                Assert.True(
                    token.RevokedAtUtc
                        .HasValue));
    }

    [Fact]
    public async Task
        RefreshToken_WhenExpired_Returns401()
    {
        const int userId =
            93003;

        const string rawToken =
            "expired-refresh-token-security-test";

        const string sessionId =
            "session-expired-refresh";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        await _factory
            .SeedRefreshTokenAsync(
                userId,
                rawToken,
                sessionId,
                expiresAtUtc:
                    DateTime.UtcNow
                        .AddMinutes(-5));

        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Auth/refresh-token",
                new
                {
                    refreshToken =
                        rawToken
                });

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }
}