using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Domain.Enums;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Reviews;

public sealed class ReviewApiTests
    : IClassFixture<
        MindBloomIntegrationTestFactory>
{
    private readonly
        MindBloomIntegrationTestFactory
        _factory;

    public ReviewApiTests(
        MindBloomIntegrationTestFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task
        PublicReviews_AreAccessibleWithoutAuthentication()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.GetAsync(
                "/api/Reviews/public?limit=6");

        Assert.Equal(
            HttpStatusCode.OK,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Create_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client =
            _factory.CreateClient();

        var response =
            await client.PostAsJsonAsync(
                "/api/Reviews",
                new CreateReviewDto
                {
                    AppointmentId = 1,
                    Rating = 5,
                    Comment = "Test"
                });

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            response.StatusCode);
    }

    [Fact]
    public async Task
        Create_ForCompletedOwnedAppointment_ReturnsCreated()
    {
        const int clientUserId = 84001;
        const int therapistUserId = 84002;

        await _factory.SeedActiveUserAsync(
            clientUserId,
            RoleConstants.Client,
            "review-client@test.local",
            "Password123!");

        var clientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "review-therapist@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        var appointmentId =
            await _factory.SeedAppointmentAsync(
                clientId,
                therapistId,
                AppointmentStatus.Completed);

        using var client =
            _factory.CreateAuthenticatedClient(
                clientUserId,
                RoleConstants.Client);

        var response =
            await client.PostAsJsonAsync(
                "/api/Reviews",
                new CreateReviewDto
                {
                    AppointmentId =
                        appointmentId,

                    Rating = 5,

                    Comment =
                        "Excellent integration test."
                });

        Assert.Equal(
            HttpStatusCode.Created,
            response.StatusCode);

        var json =
            await response.Content
                .ReadFromJsonAsync<
                    JsonElement>();

        Assert.Equal(
            "Review added successfully.",
            json.GetProperty("message")
                .GetString());
    }

    [Fact]
    public async Task
        Mine_UsesPagination()
    {
        const int clientUserId = 84003;
        const int therapistUserId = 84004;

        await _factory.SeedActiveUserAsync(
            clientUserId,
            RoleConstants.Client,
            "review-pagination-client@test.local",
            "Password123!");

        var clientId =
            await _factory
                .SeedClientProfileAsync(
                    clientUserId);

        await _factory.SeedActiveUserAsync(
            therapistUserId,
            RoleConstants.Therapist,
            "review-pagination-therapist@test.local",
            "Password123!");

        var therapistId =
            await _factory
                .SeedTherapistProfileAsync(
                    therapistUserId);

        for (var index = 0;
             index < 3;
             index++)
        {
            var appointmentId =
                await _factory
                    .SeedAppointmentAsync(
                        clientId,
                        therapistId,
                        AppointmentStatus.Completed);

            await _factory.SeedReviewAsync(
                clientId,
                therapistId,
                appointmentId);
        }

        using var client =
            _factory.CreateAuthenticatedClient(
                clientUserId,
                RoleConstants.Client);

        var response =
            await client.GetAsync(
                "/api/Reviews/mine?pageNumber=1&pageSize=2");

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