using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Authentication;

public sealed class LoginApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public LoginApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        Login_WithValidCredentials_ReturnsOkAndAuthenticationBody()
    {
        const int userId =
            71001;

        const string email =
            "integration-login@mindbloom.test";

        const string password =
            "IntegrationPassword123!";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                email,
                password);

        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Auth/login",
                new LoginRequestDto
                {
                    Email =
                        email,

                    Password =
                        password,

                    RememberMe =
                        false
                });

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            userId,
            json.GetProperty("id")
                .GetInt32());

        Assert.Equal(
            email,
            json.GetProperty("email")
                .GetString());

        Assert.Equal(
            RoleConstants.Client,
            json.GetProperty("role")
                .GetString());

        Assert.False(
            string.IsNullOrWhiteSpace(
                json.GetProperty("token")
                    .GetString()));

        Assert.False(
            string.IsNullOrWhiteSpace(
                json.GetProperty(
                        "refreshToken")
                    .GetString()));
    }

    [Fact]
    public async Task
        Login_WithWrongPassword_ReturnsUnauthorized()
    {
        const int userId =
            71002;

        const string email =
            "integration-wrong-password@mindbloom.test";

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                email,
                "CorrectPassword123!");

        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Auth/login",
                new LoginRequestDto
                {
                    Email =
                        email,

                    Password =
                        "WrongPassword123!",

                    RememberMe =
                        false
                });

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);

        var body =
            await response.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "Invalid",
            body,
            StringComparison
                .OrdinalIgnoreCase);
    }
}