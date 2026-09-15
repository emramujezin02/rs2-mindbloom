using System.Net;
using System.Net.Http.Headers;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Uploads;

public sealed class UploadApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public UploadApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        ArticleImage_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        using var content =
            CreateFakeImageContent();

        var response =
            await client.PostAsync(
                "/api/Articles/image",
                content);

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        ArticleImage_WithClientRole_ReturnsForbidden()
    {
        const int userId =
            90001;

        await _factory.SeedActiveUserAsync(
            userId,
            RoleConstants.Client,
            "upload-client@test.local",
            "Password123!");

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        using var content =
            CreateFakeImageContent();

        var response =
            await client.PostAsync(
                "/api/Articles/image",
                content);

        Assert.Equal(
            HttpStatusCode.Forbidden,
            response.StatusCode);
    }

    private static MultipartFormDataContent
        CreateFakeImageContent()
    {
        var multipart =
            new MultipartFormDataContent();

        var bytes =
            new byte[]
            {
                0xFF,
                0xD8,
                0xFF,
                0xE0
            };

        var fileContent =
            new ByteArrayContent(
                bytes);

        fileContent.Headers.ContentType =
            new MediaTypeHeaderValue(
                "image/jpeg");

        multipart.Add(
            fileContent,
            "file",
            "integration-test.jpg");

        return multipart;
    }
}