using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Articles;

public sealed class ArticleApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public ArticleApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        PublicList_WithoutAuthentication_ReturnsOk()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Articles?pageNumber=1&pageSize=10");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.True(
            json.ValueKind ==
                JsonValueKind.Object ||
            json.ValueKind ==
                JsonValueKind.Array);
    }

    [Fact]
    public async Task
        Management_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Articles/management");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Management_WithClientRole_ReturnsForbidden()
    {
        const int userId =
            87001;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "article-client@test.local",
            "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                "/api/Articles/management");

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Create_WithClientRole_ReturnsForbidden()
    {
        const int userId =
            87002;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "article-create-client@test.local",
            "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        var response =
            await client.PostAsJsonAsync(
                "/api/Articles",
                new
                {
                    title =
                        "Forbidden article",

                    description =
                        "Integration test",

                    content =
                        "Integration test content."
                });

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }
}