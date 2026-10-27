using System.Net;
using System.Net.Http.Json;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using MindBloom.API.Models;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Recommendations.Services;

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

    [Fact]
    public async Task Recommendations_WhenNoTherapistsMatch_ReturnsOkWithEmptyList()
    {
        using var factory = new MindBloomIntegrationTestFactory();
        const int userId = 72003;
        await factory.SeedActiveUserAsync(userId, RoleConstants.Client,
            "recommendation-empty@test.local", "Password123!");
        await factory.SeedClientProfileAsync(userId);
        using var client = factory.CreateAuthenticatedClient(userId, RoleConstants.Client);

        var response = await client.PostAsJsonAsync("/api/recommendations/therapists",
            new TherapistRecommendationRequestDto());

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var result = await response.Content.ReadFromJsonAsync<List<TherapistRecommendationDto>>();
        Assert.NotNull(result);
        Assert.Empty(result);
    }

    [Theory]
    [InlineData("unexpected", HttpStatusCode.InternalServerError, "internal_server_error",
        "An unexpected server error occurred.")]
    [InlineData("business", HttpStatusCode.Conflict, "business_rule_violation", "Business rule failed.")]
    [InlineData("bad_request", HttpStatusCode.BadRequest, "bad_request", "Invalid request.")]
    [InlineData("not_found", HttpStatusCode.NotFound, "not_found", "Resource missing.")]
    [InlineData("client_missing", HttpStatusCode.NotFound, "not_found", "Client profile missing.")]
    public async Task Recommendations_WhenServiceThrows_ReturnsMiddlewareError(
        string failure, HttpStatusCode expectedStatus, string expectedCode, string expectedDetail)
    {
        const int userId = 72004;
        await _factory.SeedActiveUserAsync(userId, RoleConstants.Client,
            "recommendation-failure@test.local", "Password123!");
        using var application = _factory.WithWebHostBuilder(builder =>
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IRecommendationService>();
                services.AddSingleton<IRecommendationService>(new FailingRecommendationService(failure));
            }));
        using var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Test-UserId", userId.ToString());
        client.DefaultRequestHeaders.Add("X-Test-Role", RoleConstants.Client);

        var response = await client.PostAsJsonAsync("/api/recommendations/therapists",
            new TherapistRecommendationRequestDto());

        Assert.Equal(expectedStatus, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var error = await response.Content.ReadFromJsonAsync<ApiErrorResponse>();
        Assert.NotNull(error);
        Assert.Equal((int)expectedStatus, error.StatusCode);
        Assert.Equal(expectedCode, error.ErrorCode);
        Assert.Equal(expectedDetail, error.Detail);
        Assert.False(string.IsNullOrWhiteSpace(error.TraceId));
        Assert.Null(error.StackTrace);
        Assert.Null(error.ExceptionType);
    }

    private sealed class FailingRecommendationService(string failure) : IRecommendationService
    {
        public Task<IReadOnlyList<TherapistRecommendationDto>> GetRecommendationsAsync(
            int userId, TherapistRecommendationRequestDto request, CancellationToken cancellationToken = default)
        {
            Exception exception = failure switch
            {
                "business" => new BusinessException("Business rule failed."),
                "bad_request" => new BadRequestException("Invalid request."),
                "not_found" => new NotFoundException("Resource missing."),
                "client_missing" => new KeyNotFoundException("Client profile missing."),
                _ => new Exception("Unexpected recommendation failure.")
            };
            return Task.FromException<IReadOnlyList<TherapistRecommendationDto>>(exception);
        }
    }
}
