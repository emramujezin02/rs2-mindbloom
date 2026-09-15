using System.Net;
using System.Net.Http.Headers;
using MindBloom.SecurityTests.Infrastructure;
using MindBloom.Shared.Constants;
using Xunit;

namespace MindBloom.SecurityTests.Authorization;

public sealed class AuthorizationSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public AuthorizationSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        ProtectedEndpoint_WithoutToken_Returns401()
    {
        using var client =
            _factory.CreateClient(
                new Microsoft.AspNetCore.Mvc.Testing
                    .WebApplicationFactoryClientOptions
                {
                    AllowAutoRedirect =
                        false
                });

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        AdminEndpoint_WithClientRole_Returns403()
    {
        const int userId =
            91001;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client);

        var token =
            TestJwtTokenFactory
                .CreateValidToken(
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
                "/api/Articles/management");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ClientOnlyEndpoint_WithTherapistRole_Returns403()
    {
        const int userId =
            91002;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Therapist);

        var token =
            TestJwtTokenFactory
                .CreateValidToken(
                    userId,
                    RoleConstants.Therapist);

        using var client =
            _factory.CreateClient();

        client.DefaultRequestHeaders
            .Authorization =
            new AuthenticationHeaderValue(
                "Bearer",
                token);

        var response =
            await client.GetAsync(
                "/api/Workshops/mine");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }
}