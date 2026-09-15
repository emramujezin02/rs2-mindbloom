using System.Net;
using System.Net.Http.Json;
using MindBloom.SecurityTests.Infrastructure;
using Xunit;

namespace MindBloom.SecurityTests.RateLimiting;

public sealed class RateLimitingSecurityTests
    : IClassFixture<
        MindBloomWebApplicationFactory>
{
    private readonly
        MindBloomWebApplicationFactory
        _factory;

    public RateLimitingSecurityTests(
        MindBloomWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        LoginRateLimit_TooManyRequests_Returns429()
    {
        using var client =
            _factory.CreateClient();

        HttpResponseMessage? rateLimitedResponse =
            null;

        /*
         * Login policy ima PermitLimit = 5.
         * Šaljemo nekoliko zahtjeva više od limita.
         */
        for (var attempt = 0;
             attempt < 8;
             attempt++)
        {
            var response =
                await client.PostAsJsonAsync(
                    "/api/Auth/login",
                    new
                    {
                        email =
                            "rate-limit-nonexistent@mindbloom.test",

                        password =
                            "WrongPassword123!"
                    });

            if (response.StatusCode ==
                HttpStatusCode.TooManyRequests)
            {
                rateLimitedResponse =
                    response;

                break;
            }

            response.Dispose();
        }

        Assert.NotNull(
            rateLimitedResponse);

        Assert.Equal(
            HttpStatusCode.TooManyRequests,
            rateLimitedResponse!
                .StatusCode);

        rateLimitedResponse.Dispose();
    }

    [Fact]
    public async Task
        LoginRateLimit_WhenRejected_ContainsRetryAfterHeader()
    {
        using var client =
            _factory.CreateClient();

        HttpResponseMessage? rateLimitedResponse =
            null;

        for (var attempt = 0;
             attempt < 8;
             attempt++)
        {
            var response =
                await client.PostAsJsonAsync(
                    "/api/Auth/login",
                    new
                    {
                        email =
                            "retry-after@mindbloom.test",

                        password =
                            "WrongPassword123!"
                    });

            if (response.StatusCode ==
                HttpStatusCode.TooManyRequests)
            {
                rateLimitedResponse =
                    response;

                break;
            }

            response.Dispose();
        }

        Assert.NotNull(
            rateLimitedResponse);

        Assert.True(
            rateLimitedResponse!
                .Headers
                .Contains(
                    "Retry-After"));

        rateLimitedResponse.Dispose();
    }
}