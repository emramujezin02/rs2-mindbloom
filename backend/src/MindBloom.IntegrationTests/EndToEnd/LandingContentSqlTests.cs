using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class LandingContentSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Fact]
    public async Task MigrationAndSeed_PreserveHistoryAndRespectExplicitAdministratorChoices()
    {
        using var scope = factory.Services.CreateScope();
        var original = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var connection = new SqlConnectionStringBuilder(original.Database.GetConnectionString());
        Assert.StartsWith("MindBloomE2E_", connection.InitialCatalog);
        connection.InitialCatalog = $"Task19Migration_{Guid.NewGuid():N}";
        var options = new DbContextOptionsBuilder<ApplicationDbContext>().UseSqlServer(connection.ConnectionString).Options;
        await using var db = new ApplicationDbContext(options);
        try
        {
            await db.GetService<IMigrator>().MigrateAsync("20261029090907_AllowSystemAppointmentStatusAudits");
            int authorId, reviewId;
            await using (var legacy = new LegacyContext(options))
            {
                var review = ReviewGraph();
                legacy.Add(review);
                legacy.TherapyApproaches.AddRange(TherapyApproachArticleSeeder.Articles.Select(x => new TherapyApproach { Name = x.ApproachName, IsActive = true }));
                for (var i = 0; i < 4; i++) legacy.Add(new Article { Title = "Original article " + i, Description = "Original", Content = "Preserve this content", AuthorUser = review.Therapist.User, IsPublished = true });
                await legacy.SaveChangesAsync(); authorId = review.Therapist.UserId; reviewId = review.Id;
            }
            await db.GetService<IMigrator>().MigrateAsync();
            Assert.Equal(85, (await db.Database.GetAppliedMigrationsAsync()).Count());
            Assert.False((await db.Reviews.SingleAsync()).ShareAuthorDemographics);
            Assert.All(await db.TherapyApproaches.ToListAsync(), x => Assert.Null(x.FeaturedArticleId));
            await TherapyApproachArticleSeeder.SeedAsync(db, authorId);
            await TherapyApproachArticleSeeder.SeedAsync(db, authorId);
            Assert.Equal(8, await db.Articles.CountAsync());
            Assert.Equal(4, await db.Articles.CountAsync(x => x.Content == "Preserve this content"));
            foreach (var seed in TherapyApproachArticleSeeder.Articles)
            {
                var approach = await db.TherapyApproaches.Include(x => x.FeaturedArticle).SingleAsync(x => x.Name == seed.ApproachName);
                Assert.Equal(seed.Key, approach.FeaturedArticle!.SeedKey);
                Assert.Equal(seed.Title, approach.FeaturedArticle.Title);
                Assert.Contains("https://", approach.FeaturedArticle.Content);
                Assert.True(approach.FeaturedArticle.IsPublished);
            }
            var first = await db.TherapyApproaches.OrderBy(x => x.Id).FirstAsync();
            var article = await db.Articles.SingleAsync(x => x.Id == first.FeaturedArticleId);
            article.Title = "Administrator renamed this article";
            var service = new ReferenceDataService(db);
            await service.UpdateTherapyApproachAsync(first.Id, new UpdateTherapyApproachDto { Name = first.Name, UpdateFeaturedArticle = true });
            await TherapyApproachArticleSeeder.SeedAsync(db, authorId);
            Assert.Null(first.FeaturedArticleId);
            Assert.Equal(8, await db.Articles.CountAsync());
            Assert.Equal("Administrator renamed this article", article.Title);
            Assert.Equal(reviewId, (await db.Reviews.SingleAsync()).Id);
            Assert.Equal(ReviewModerationStatus.Approved, (await db.Reviews.SingleAsync()).ModerationStatus);
            // SQL enforces the real FK, independently of API validation.
            first.FeaturedArticleId = int.MaxValue;
            await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        }
        finally
        {
            Assert.StartsWith("Task19Migration_", db.Database.GetDbConnection().Database);
            await db.Database.EnsureDeletedAsync();
        }
    }

    [Fact]
    public async Task SqlProjection_ConsentPrivacyModerationAndPublishedArticleVisibility()
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var review = ReviewGraph(); db.Add(review); await db.SaveChangesAsync();
        var reviews = new ReviewService(db, scope.ServiceProvider.GetRequiredService<IBusinessNotificationService>());
        var request = new UpdateReviewDto { Rating = 5, Comment = review.Comment, ShareAuthorDemographics = true };
        await reviews.UpdateAsync(review.Client.UserId, review.Id, request);
        Assert.Equal("Female", (await reviews.GetPublicReviewsAsync(100)).Single(x => x.Id == review.Id).AuthorGender);
        review.Client.User.Settings!.ShowProfilePublicly = false; await db.SaveChangesAsync();
        Assert.Null((await reviews.GetPublicReviewsAsync(100)).Single(x => x.Id == review.Id).AuthorAge);
        review.Client.User.Settings.ShowProfilePublicly = true;
        review.Client.User.DateOfBirth = DateTime.UtcNow.Date.AddYears(-17); await db.SaveChangesAsync();
        Assert.Null((await reviews.GetPublicReviewsAsync(100)).Single(x => x.Id == review.Id).AuthorGender);
        request.ShareAuthorDemographics = false;
        await reviews.UpdateAsync(review.Client.UserId, review.Id, request);
        Assert.True(review.IsApproved);
        review.ModerationStatus = ReviewModerationStatus.Pending; await db.SaveChangesAsync();
        Assert.DoesNotContain(await reviews.GetPublicReviewsAsync(100), x => x.Id == review.Id);

        var article = new Article { AuthorUserId = review.Therapist.UserId, Title = "Explicit CBT article", Content = "Education", IsPublished = true };
        var approach = new TherapyApproach { Name = Guid.NewGuid().ToString(), FeaturedArticle = article, IsActive = true };
        db.Add(approach); await db.SaveChangesAsync();
        var references = new ReferenceDataService(db);
        Assert.Equal(article.Id, (await references.GetActiveTherapyApproachesAsync()).Single(x => x.Id == approach.Id).FeaturedArticleId);
        article.IsDeleted = true; await db.SaveChangesAsync();
        Assert.Null((await references.GetActiveTherapyApproachesAsync()).Single(x => x.Id == approach.Id).FeaturedArticleId);
        approach.IsActive = false; await db.SaveChangesAsync();
        Assert.DoesNotContain(await references.GetActiveTherapyApproachesAsync(), x => x.Id == approach.Id);
    }

    private static Review ReviewGraph()
    {
        ApplicationUser User(string first) => new() { UserName = Guid.NewGuid().ToString(), FirstName = first, LastName = "Test", Gender = "Female", DateOfBirth = new(1990, 1, 1), Settings = new UserSettings { ShowProfilePublicly = true } };
        var client = new Client { User = User("Client") };
        var therapist = new Therapist { User = User("Therapist"), Biography = "Test", Specialization = "Test", VerificationStatus = TherapistVerificationStatus.Approved };
        return new Review { Client = client, Therapist = therapist, Appointment = new Appointment { Client = client, Therapist = therapist, Status = AppointmentStatus.Completed, StartUtc = DateTime.UtcNow.AddHours(-2), EndUtc = DateTime.UtcNow.AddHours(-1) }, Rating = 5, Comment = "Helpful session.", IsApproved = true, ModerationStatus = ReviewModerationStatus.Approved };
    }

    private sealed class LegacyContext(DbContextOptions<ApplicationDbContext> options) : ApplicationDbContext(options)
    {
        protected override void OnModelCreating(ModelBuilder model)
        {
            base.OnModelCreating(model);
            model.Entity<TherapyApproach>().Ignore(x => x.FeaturedArticle).Ignore(x => x.FeaturedArticleId);
            model.Entity<Review>().Ignore(x => x.ShareAuthorDemographics);
            model.Entity<Article>().Ignore(x => x.SeedKey);
        }
    }
}
