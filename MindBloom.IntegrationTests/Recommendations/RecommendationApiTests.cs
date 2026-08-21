using System.Net;
using System.Net.Http.Json;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Recommendations;

public sealed class RecommendationApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public RecommendationApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        Recommendations_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/recommendations/therapists",
                new TherapistRecommendationRequestDto());

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Recommendations_WithTherapistRole_ReturnsForbidden()
    {
        const int userId =
            72001;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Therapist,
                "integration-recommendation-therapist@mindbloom.test",
                "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Therapist);

        var response =
            await client.PostAsJsonAsync(
                "/api/recommendations/therapists",
                new TherapistRecommendationRequestDto());

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Recommendations_WithClient_ReturnsOkAndResponseBody()
    {
        const int userId =
            72002;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                "integration-recommendation-client@mindbloom.test",
                "Password123!");

        await _factory
            .SeedClientProfileAsync(
                userId);

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        var response =
            await client.PostAsJsonAsync(
                "/api/recommendations/therapists",
                new TherapistRecommendationRequestDto
                {
                    Take = 10
                });

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var result =
            await response.Content
                .ReadFromJsonAsync<
                    List<
                        TherapistRecommendationDto>>();

        Assert.NotNull(result);
    }
}