using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MindBloom.Domain.Enums;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Workshops;

public sealed class WorkshopApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public WorkshopApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        PublicList_IsAccessibleWithoutAuthentication()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Workshops?pageNumber=1&pageSize=10");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Manage_WithClientRole_ReturnsForbidden()
    {
        const int userId = 85001;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "workshop-client-role@test.local",
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
                "/api/Workshops/manage");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        GetById_ReturnsWorkshopResponseBody()
    {
        const int organizerUserId = 85002;

        await _factory.SeedActiveUserAsync(
            organizerUserId,
            RoleConstants.Admin,
            "workshop-admin@test.local",
            "Password123!");

        var workshopId =
            await _factory.SeedWorkshopAsync(
                organizerUserId);

        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                $"/api/Workshops/{workshopId}");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            workshopId,
            json.GetProperty("id")
                .GetInt32());

        Assert.Equal(
            "Integration Workshop",
            json.GetProperty("title")
                .GetString());
    }

    [Fact]
    public async Task
        PublicList_RespectsPagination()
    {
        const int organizerUserId = 85003;

        await _factory.SeedActiveUserAsync(
            organizerUserId,
            RoleConstants.Admin,
            "workshop-pagination-admin@test.local",
            "Password123!");

        await _factory.SeedWorkshopAsync(
            organizerUserId);

        await _factory.SeedWorkshopAsync(
            organizerUserId);

        await _factory.SeedWorkshopAsync(
            organizerUserId);

        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Workshops?pageNumber=1&pageSize=2");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            2,
            json.GetProperty("items")
                .GetArrayLength());
    }
}