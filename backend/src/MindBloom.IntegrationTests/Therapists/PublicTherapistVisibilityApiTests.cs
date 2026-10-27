using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Therapists;

public sealed class PublicTherapistVisibilityApiTests
{
    [Theory]
    [InlineData("public", true)]
    [InlineData("pending", false)]
    [InlineData("rejected", false)]
    [InlineData("requires_changes", false)]
    [InlineData("deleted", false)]
    [InlineData("inactive", false)]
    [InlineData("blocked", false)]
    [InlineData("hidden", false)]
    public async Task PublicEndpoints_EnforceVisibility(string state, bool visible)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        var (therapistId, _) = await SeedAsync(factory, state);
        using var client = factory.CreateClient();

        var all = await client.GetFromJsonAsync<JsonElement>("/api/Therapists");
        Assert.Equal(visible ? 1 : 0, all.GetProperty("items").GetArrayLength());
        var filterResponse = await client.PostAsJsonAsync("/api/Therapists/filter",
            new TherapistFilterDto { MinPrice = 40m, MaxPrice = 60m, SortByRating = true });
        Assert.Equal(HttpStatusCode.OK, filterResponse.StatusCode);
        var filtered = await filterResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(visible ? 1 : 0, filtered.GetProperty("items").GetArrayLength());
        var search = await client.GetFromJsonAsync<JsonElement>("/api/Therapists/search?pageNumber=1&pageSize=1");
        Assert.Equal(visible ? 1 : 0, search.GetProperty("totalCount").GetInt32());
        Assert.Equal(visible ? 1 : 0, search.GetProperty("items").GetArrayLength());
        Assert.Equal(visible ? HttpStatusCode.OK : HttpStatusCode.NotFound,
            (await client.GetAsync($"/api/Therapists/{therapistId}")).StatusCode);
        var publicReviews = await client.GetFromJsonAsync<JsonElement>("/api/Reviews/public");
        Assert.Equal(visible ? 1 : 0, publicReviews.GetArrayLength());
        foreach (var route in new[]
        {
            $"/api/Reviews/therapist/{therapistId}", $"/api/Reviews/therapist/{therapistId}/rating",
            $"/api/Therapists/{therapistId}/availability", $"/api/Therapists/{therapistId}/unavailable-dates",
            $"/api/Memberships/therapist/{therapistId}/plans"
        })
        {
            Assert.Equal(visible ? HttpStatusCode.OK : HttpStatusCode.NotFound,
                (await client.GetAsync(route)).StatusCode);
        }
        using var authenticated = factory.CreateAuthenticatedClient(93001, RoleConstants.Client);
        var recommendationResponse = await authenticated.PostAsJsonAsync("/api/recommendations/therapists",
            new TherapistRecommendationRequestDto());
        Assert.Equal(HttpStatusCode.OK, recommendationResponse.StatusCode);
        var recommendations = await recommendationResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(visible ? 1 : 0, recommendations.GetArrayLength());
        Assert.Equal(visible ? HttpStatusCode.OK : HttpStatusCode.NotFound,
            (await authenticated.GetAsync($"/api/Appointments/therapist/{therapistId}/occupied-slots?date=2026-11-01")).StatusCode);
    }

    [Theory]
    [InlineData(true, 4.5, 2)]
    [InlineData(false, 0, 0)]
    public async Task PublicRatingResponses_ExcludeUnapprovedReviews(bool approved, double average, int count)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        var (therapistId, clientId) = await SeedAsync(factory, "public", addReview: false);
        using (var scope = factory.Services.CreateScope())
        {
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            if (approved)
            {
                context.Reviews.AddRange(CreateReview(therapistId, clientId, 5, true),
                    CreateReview(therapistId, clientId, 4, true));
            }
            context.Reviews.Add(CreateReview(therapistId, clientId, 1, false));
            var deleted = CreateReview(therapistId, clientId, 1, true);
            deleted.IsDeleted = true;
            context.Reviews.Add(deleted);
            await context.SaveChangesAsync();
        }
        using var client = factory.CreateClient();
        var all = await client.GetFromJsonAsync<JsonElement>("/api/Therapists");
        var search = await client.GetFromJsonAsync<JsonElement>("/api/Therapists/search?sortBy=rating");
        var filterResponse = await client.PostAsJsonAsync("/api/Therapists/filter", new TherapistFilterDto());
        var filter = await filterResponse.Content.ReadFromJsonAsync<JsonElement>();
        var details = await client.GetFromJsonAsync<JsonElement>($"/api/Therapists/{therapistId}");
        var rating = await client.GetFromJsonAsync<JsonElement>($"/api/Reviews/therapist/{therapistId}/rating");
        foreach (var item in new[] { all.GetProperty("items")[0], search.GetProperty("items")[0], filter.GetProperty("items")[0], details, rating })
        {
            Assert.Equal(average, item.GetProperty("averageRating").GetDouble());
            Assert.Equal(count, item.GetProperty("totalReviews").GetInt32());
        }
        using var authenticated = factory.CreateAuthenticatedClient(93001, RoleConstants.Client);
        var response = await authenticated.PostAsJsonAsync("/api/recommendations/therapists", new TherapistRecommendationRequestDto());
        var recommendation = (await response.Content.ReadFromJsonAsync<JsonElement>())[0];
        Assert.Equal(average, recommendation.GetProperty("averageRating").GetDouble());
        Assert.Equal(count, recommendation.GetProperty("reviewCount").GetInt32());
    }

    [Fact]
    public async Task HiddenProfile_PreservesOwnProfileScheduleAndAdminVerificationAccess()
    {
        using var factory = new MindBloomIntegrationTestFactory();
        var (therapistId, _) = await SeedAsync(factory, "hidden");
        await factory.SeedActiveUserAsync(93003, RoleConstants.Admin, "visibility-admin@test.local", "Password123!");
        using var owner = factory.CreateAuthenticatedClient(93002, RoleConstants.Therapist);
        foreach (var route in new[] { "/api/Therapists/profile",
            $"/api/Therapists/{therapistId}/availability", $"/api/Therapists/{therapistId}/unavailable-dates" })
        {
            Assert.Equal(HttpStatusCode.OK, (await owner.GetAsync(route)).StatusCode);
        }
        Assert.Equal(HttpStatusCode.NotFound, (await owner.GetAsync($"/api/Therapists/{therapistId}")).StatusCode);
        using var client = factory.CreateAuthenticatedClient(93001, RoleConstants.Client);
        Assert.Equal(HttpStatusCode.NotFound,
            (await client.GetAsync($"/api/Therapists/{therapistId}/availability?currentUserId=93002")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await client.GetAsync($"/api/Admin/therapists/{therapistId}/verification")).StatusCode);
        using var admin = factory.CreateAuthenticatedClient(93003, RoleConstants.Admin);
        foreach (var state in new[] { TherapistVerificationStatus.Pending, TherapistVerificationStatus.Rejected })
        {
            using (var scope = factory.Services.CreateScope())
            {
                var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
                var therapist = await context.Therapists.Include(x => x.User).SingleAsync(x => x.Id == therapistId);
                therapist.VerificationStatus = state;
                therapist.User.IsBlocked = true;
                await context.SaveChangesAsync();
            }
            var response = await admin.GetAsync($"/api/Admin/therapists/{therapistId}/verification");
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var json = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(state.ToString(), json.GetProperty("verificationStatus").GetString());
            Assert.Equal(HttpStatusCode.OK, (await admin.GetAsync("/api/Admin/therapists/pending")).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await admin.GetAsync($"/api/Therapists/{therapistId}/documents")).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await admin.GetAsync($"/api/Therapists/{therapistId}/availability")).StatusCode);
            Assert.Equal(HttpStatusCode.OK, (await admin.GetAsync($"/api/Therapists/{therapistId}/unavailable-dates")).StatusCode);
        }
    }

    private static async Task<(int TherapistId, int ClientId)> SeedAsync(
        MindBloomIntegrationTestFactory factory, string state, bool addReview = true)
    {
        await factory.SeedActiveUserAsync(93001, RoleConstants.Client, "visibility-client@test.local", "Password123!");
        await factory.SeedActiveUserAsync(93002, RoleConstants.Therapist, "visibility-therapist@test.local", "Password123!");
        var clientId = await factory.SeedClientProfileAsync(93001);
        var therapistId = await factory.SeedTherapistProfileAsync(93002);
        using var scope = factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var therapist = await context.Therapists.Include(x => x.User).ThenInclude(x => x.Settings)
            .SingleAsync(x => x.Id == therapistId);
        therapist.User.Settings ??= new UserSettings { UserId = therapist.UserId };
        switch (state)
        {
            case "pending": therapist.VerificationStatus = TherapistVerificationStatus.Pending; break;
            case "rejected": therapist.VerificationStatus = TherapistVerificationStatus.Rejected; break;
            case "requires_changes": therapist.VerificationStatus = TherapistVerificationStatus.RequiresChanges; break;
            case "deleted": therapist.IsDeleted = true; break;
            case "inactive": therapist.User.IsActive = false; break;
            case "blocked": therapist.User.IsBlocked = true; break;
            case "hidden": therapist.User.Settings.ShowProfilePublicly = false; break;
        }
        if (addReview) context.Reviews.Add(CreateReview(therapistId, clientId, 5, true));
        await context.SaveChangesAsync();
        return (therapistId, clientId);
    }

    private static Review CreateReview(int therapistId, int clientId, int rating, bool approved) => new()
    {
        TherapistId = therapistId, ClientId = clientId, Rating = rating, Comment = "Public visibility test",
        IsApproved = approved, ModerationStatus = approved ? ReviewModerationStatus.Approved : ReviewModerationStatus.Pending
    };
}
