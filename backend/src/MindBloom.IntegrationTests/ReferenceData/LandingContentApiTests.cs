using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;

namespace MindBloom.IntegrationTests.ReferenceData;

public sealed class LandingContentApiTests
{
    [Fact]
    public async Task AdminCanAssignReplaceClear_AnonymousSeesOnlyPublishedLinks()
    {
        using var factory = new MindBloomIntegrationTestFactory();
        using var client = factory.CreateClient();
        int id, first, second, draft;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var author = new ApplicationUser { FirstName = "Admin", LastName = "Test" };
            Article Article(string title, bool published) => new() { Title = title, Content = "Education", Description = "Summary", AuthorUser = author, IsPublished = published };
            var a = Article("CBT", true); var b = Article("Gestalt", true); var c = Article("Draft", false);
            var approach = new TherapyApproach { Name = "CBT", IsActive = true };
            db.AddRange(a, b, c, approach); await db.SaveChangesAsync();
            id = approach.Id; first = a.Id; second = b.Id; draft = c.Id;
        }
        var url = $"/api/reference-data/therapy-approaches/{id}";
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.PutAsJsonAsync(url, new { name = "CBT", featuredArticleId = first })).StatusCode);
        client.DefaultRequestHeaders.Add(TestAuthenticationHandler.UserIdHeader, "123");
        client.DefaultRequestHeaders.Add(TestAuthenticationHandler.RoleHeader, "Therapist");
        Assert.Equal(HttpStatusCode.Forbidden, (await client.PutAsJsonAsync(url, new { name = "CBT", featuredArticleId = first })).StatusCode);
        client.DefaultRequestHeaders.Remove(TestAuthenticationHandler.RoleHeader);
        client.DefaultRequestHeaders.Add(TestAuthenticationHandler.RoleHeader, "Admin");
        foreach (var articleId in new[] { first, second })
        {
            Assert.True((await client.PutAsJsonAsync(url, new { name = "CBT", featuredArticleId = articleId })).IsSuccessStatusCode);
            var json = await client.GetFromJsonAsync<JsonElement>("/api/TherapyApproaches/public");
            Assert.Equal(articleId, json[0].GetProperty("featuredArticleId").GetInt32());
        }
        foreach (var invalid in new[] { draft, 999999 })
            Assert.Equal(HttpStatusCode.BadRequest, (await client.PutAsJsonAsync(url, new { name = "CBT", featuredArticleId = invalid })).StatusCode);
        // A legacy client omitting the field must not erase an administrator's link.
        Assert.True((await client.PutAsJsonAsync(url, new { name = "CBT" })).IsSuccessStatusCode);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var article = await db.Articles.SingleAsync(x => x.Id == second);
            article.IsPublished = false; await db.SaveChangesAsync();
        }
        var hidden = await client.GetFromJsonAsync<JsonElement>("/api/TherapyApproaches/public");
        Assert.Equal(JsonValueKind.Null, hidden[0].GetProperty("featuredArticleId").ValueKind);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/Articles/{second}")).StatusCode);
        Assert.True((await client.PutAsJsonAsync(url, new { name = "CBT", updateFeaturedArticle = true, featuredArticleId = (int?)null })).IsSuccessStatusCode);
        using var finalScope = factory.Services.CreateScope();
        var finalDb = finalScope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Null((await finalDb.TherapyApproaches.SingleAsync()).FeaturedArticleId);
        Assert.Equal(3, await finalDb.Articles.CountAsync());
    }

    [Fact]
    public async Task PublicReview_ConsentIsRevocableAndResponseContainsNoPrivateFields()
    {
        using var factory = new MindBloomIntegrationTestFactory();
        using var client = factory.CreateClient();
        int reviewId, userId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var author = new Client { User = new ApplicationUser { FirstName = "Anna", LastName = "Mason", Gender = "Female", DateOfBirth = DateTime.UtcNow.Date.AddYears(-30), Settings = new UserSettings { ShowProfilePublicly = true } } };
            var therapist = new Therapist { User = new ApplicationUser { FirstName = "Test", LastName = "Therapist" }, Biography = "Test", Specialization = "Test", VerificationStatus = TherapistVerificationStatus.Approved };
            var review = new Review { Client = author, Therapist = therapist, Rating = 5, Comment = "A helpful session.", IsApproved = true, ModerationStatus = ReviewModerationStatus.Approved };
            db.Add(review); await db.SaveChangesAsync(); reviewId = review.Id; userId = author.UserId;
        }
        var before = await client.GetFromJsonAsync<JsonElement>("/api/Reviews/public");
        Assert.Equal(JsonValueKind.Null, before[0].GetProperty("authorAge").ValueKind);
        client.DefaultRequestHeaders.Add(TestAuthenticationHandler.UserIdHeader, userId.ToString());
        client.DefaultRequestHeaders.Add(TestAuthenticationHandler.RoleHeader, "Client");
        foreach (var consent in new[] { true, false })
        {
            var response = await client.PutAsJsonAsync($"/api/Reviews/{reviewId}", new { rating = 5, comment = "A helpful session.", shareAuthorDemographics = consent });
            Assert.True(response.IsSuccessStatusCode, await response.Content.ReadAsStringAsync());
            var json = await client.GetFromJsonAsync<JsonElement>("/api/Reviews/public");
            Assert.Equal(consent ? JsonValueKind.Number : JsonValueKind.Null, json[0].GetProperty("authorAge").ValueKind);
            foreach (var field in new[] { "dateOfBirth", "email", "phoneNumber", "clientId", "userId" })
                Assert.False(json[0].TryGetProperty(field, out _));
            Assert.Equal(5, json[0].GetProperty("rating").GetInt32());
            Assert.Equal("A helpful session.", json[0].GetProperty("comment").GetString());
        }
    }
}
