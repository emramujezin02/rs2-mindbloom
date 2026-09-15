using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Users;

public sealed class ProfileApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public ProfileApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory =
            factory;
    }

    [Fact]
    public async Task
        GetMyProfile_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        GetMyProfile_ReturnsOnlyAuthenticatedUsersProfile()
    {
        const int firstUserId =
            73001;

        const int secondUserId =
            73002;

        await _factory
            .SeedActiveUserAsync(
                firstUserId,
                RoleConstants.Client,
                "first-profile@mindbloom.test",
                "Password123!");

        await _factory
            .SeedClientProfileAsync(
                firstUserId);

        await _factory
            .SeedActiveUserAsync(
                secondUserId,
                RoleConstants.Client,
                "second-profile@mindbloom.test",
                "Password123!");

        await _factory
            .SeedClientProfileAsync(
                secondUserId);

        using var client =
            _factory.CreateAuthenticatedClient(
                firstUserId,
                RoleConstants.Client,
                "first-profile@mindbloom.test");

        var response =
            await client.GetAsync(
                "/api/Users/me");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            "first-profile@mindbloom.test",
            json.GetProperty("email")
                .GetString());

        Assert.NotEqual(
            "second-profile@mindbloom.test",
            json.GetProperty("email")
                .GetString());
    }

    [Fact]
    public async Task
        UpdateMyProfile_WithInvalidPriceRange_ReturnsBadRequest()
    {
        const int userId =
            73003;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                "profile-validation@mindbloom.test",
                "Password123!");

        await _factory
            .SeedClientProfileAsync(
                userId);

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client);

        var response =
            await client.PutAsJsonAsync(
                "/api/Users/me",
                new UpdateUserProfileDto
                {
                    FirstName =
                        "Integration",

                    LastName =
                        "Client",

                    DateOfBirth =
                        new DateTime(
                            1995,
                            1,
                            1),

                    MinimumPricePerSession =
                        100m,

                    MaximumPricePerSession =
                        50m,

                    PreferredLanguages =
                        []
                });

        Assert.Equal(
            HttpStatusCode.BadRequest,
            response.StatusCode);

        var body =
            await response.Content
                .ReadAsStringAsync();

        Assert.Contains(
            "Minimum price cannot be greater than maximum price",
            body,
            StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task
        UpdateMyProfile_WithValidRequest_ReturnsUpdatedProfile()
    {
        const int userId =
            73004;

        await _factory
            .SeedActiveUserAsync(
                userId,
                RoleConstants.Client,
                "profile-update@mindbloom.test",
                "Password123!");

        await _factory
            .SeedClientProfileAsync(
                userId);

        using var client =
            _factory.CreateAuthenticatedClient(
                userId,
                RoleConstants.Client,
                "profile-update@mindbloom.test");

        var response =
            await client.PutAsJsonAsync(
                "/api/Users/me",
                new UpdateUserProfileDto
                {
                    FirstName =
                        "Updated",

                    LastName =
                        "Client",

                    PhoneNumber =
                        "+38761111222",

                    DateOfBirth =
                        new DateTime(
                            1995,
                            1,
                            1),

                    Location =
                        "Mostar",

                    PreferredTherapistGender =
                        "Any",

                    PreferredSessionType =
                        "Online",

                    MinimumPricePerSession =
                        30m,

                    MaximumPricePerSession =
                        80m,

                    PreferredLanguages =
                        [
                            "English",
                            "Bosnian"
                        ]
                });

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            "Updated",
            json.GetProperty("firstName")
                .GetString());

        Assert.Equal(
            "Client",
            json.GetProperty("lastName")
                .GetString());

        Assert.Equal(
            "Mostar",
            json.GetProperty("location")
                .GetString());
    }
}