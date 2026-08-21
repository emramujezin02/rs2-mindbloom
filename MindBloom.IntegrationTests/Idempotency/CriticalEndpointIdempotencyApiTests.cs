using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Http;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Idempotency;

public sealed class CriticalEndpointIdempotencyApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public CriticalEndpointIdempotencyApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        WorkshopRegister_WithoutIdempotencyKey_ReturnsConflict()
    {
        const int userId =
            86001;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "idempotency-missing@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                userId);

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        var response =
            await client.PostAsync(
                "/api/Workshops/999/register",
                null);

        Assert.Equal(
            HttpStatusCode.Conflict,
            response.StatusCode);

        var body =
            await response.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "required",
            body,
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task
        WorkshopRegister_SameCompletedKey_ReplaysStoredResponse()
    {
        const int userId =
            86002;

        const int workshopId =
            55001;

        const string key =
            "integration-idempotency-replay";

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "idempotency-replay@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                userId);

        const string responseBody =
            """
            {
              "message":
              "You have successfully registered for the workshop."
            }
            """;

        await _factory
            .SeedCompletedIdempotencyRecordAsync(
                key,
                userId,
                "Workshops.Register",
                new
                {
                    id =
                        workshopId
                },
                StatusCodes.Status200OK,
                responseBody);

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        client.DefaultRequestHeaders.Add(
            _factory
                .GetIdempotencyHeaderName(),
            key);

        var response =
            await client.PostAsync(
                $"/api/Workshops/{workshopId}/register",
                null);

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            "You have successfully registered for the workshop.",
            json.GetProperty("message")
                .GetString());
    }

    [Fact]
    public async Task
        WorkshopRegister_SameKeyWithDifferentPayload_ReturnsConflict()
    {
        const int userId =
            86003;

        const int originalWorkshopId =
            56001;

        const int differentWorkshopId =
            56002;

        const string key =
            "integration-idempotency-payload-conflict";

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "idempotency-payload@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                userId);

        await _factory
            .SeedCompletedIdempotencyRecordAsync(
                key,
                userId,
                "Workshops.Register",
                new
                {
                    id =
                        originalWorkshopId
                },
                StatusCodes.Status200OK,
                """
                {"message":"Stored response"}
                """);

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        client.DefaultRequestHeaders.Add(
            _factory
                .GetIdempotencyHeaderName(),
            key);

        var response =
            await client.PostAsync(
                $"/api/Workshops/{differentWorkshopId}/register",
                null);

        Assert.Equal(
            HttpStatusCode.Conflict,
            response.StatusCode);

        var body =
            await response.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "different request",
            body,
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task
        WorkshopRegister_KeyOwnedByAnotherUser_ReturnsConflict()
    {
        const int firstUserId =
            86004;

        const int secondUserId =
            86005;

        const int workshopId =
            57001;

        const string key =
            "integration-idempotency-user-conflict";

        await _factory.SeedActiveUserAsync(
            firstUserId,
            RoleConstants.Client,
            "idempotency-owner@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                firstUserId);

        await _factory.SeedActiveUserAsync(
            secondUserId,
            RoleConstants.Client,
            "idempotency-other@test.local",
            "Password123!");

        await _factory
            .SeedClientProfileAsync(
                secondUserId);

        await _factory
            .SeedCompletedIdempotencyRecordAsync(
                key,
                firstUserId,
                "Workshops.Register",
                new
                {
                    id =
                        workshopId
                },
                StatusCodes.Status200OK,
                """
                {"message":"Stored response"}
                """);

        using var client =
            _factory.CreateAuthenticatedClient(
                secondUserId,
                RoleConstants.Client);

        client.DefaultRequestHeaders.Add(
            _factory
                .GetIdempotencyHeaderName(),
            key);

        var response =
            await client.PostAsync(
                $"/api/Workshops/{workshopId}/register",
                null);

        Assert.Equal(
            HttpStatusCode.Conflict,
            response.StatusCode);

        var body =
            await response.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "another user",
            body,
            StringComparison.OrdinalIgnoreCase);
    }
}