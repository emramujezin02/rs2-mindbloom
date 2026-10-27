using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Application.Features.Security.Interfaces;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Queries;
using MindBloom.Infrastructure.Recommendations;
using MindBloom.Infrastructure.Services;
using MindBloom.Shared.Observability;
using Moq;

namespace MindBloom.UnitTests.Therapists;

public sealed partial class PublicTherapistVisibilityTests
{
    [Theory]
    [InlineData("public", true)]
    [InlineData("no_settings", true)]
    [InlineData("pending", false)]
    [InlineData("rejected", false)]
    [InlineData("requires_changes", false)]
    [InlineData("deleted", false)]
    [InlineData("inactive", false)]
    [InlineData("blocked", false)]
    [InlineData("hidden", false)]
    public async Task PublicQueries_ApplyAllVisibilityConditions(string state, bool visible)
    {
        await using var context = CreateContext();
        var (therapist, client) = await SeedAsync(context);
        switch (state)
        {
            case "no_settings": context.UserSettings.Remove(therapist.User.Settings!); break;
            case "pending": therapist.VerificationStatus = TherapistVerificationStatus.Pending; break;
            case "rejected": therapist.VerificationStatus = TherapistVerificationStatus.Rejected; break;
            case "requires_changes": therapist.VerificationStatus = TherapistVerificationStatus.RequiresChanges; break;
            case "deleted": therapist.IsDeleted = true; break;
            case "inactive": therapist.User.IsActive = false; break;
            case "blocked": therapist.User.IsBlocked = true; break;
            case "hidden": therapist.User.Settings!.ShowProfilePublicly = false; break;
        }
        AddReview(context, therapist, client, 5, true);
        await context.SaveChangesAsync();
        var service = CreateService(context);

        Assert.Equal(visible ? 1 : 0, (await service.GetAllAsync()).Items.Count);
        Assert.Equal(visible ? 1 : 0, (await service.FilterAsync(new TherapistFilterDto
        {
            Specialization = "therapy", MinPrice = 40m, MaxPrice = 60m, SortByRating = true
        })).Items.Count);
        var search = await service.SearchAsync(new SearchTherapistsDto { PageNumber = 1, PageSize = 1 });
        Assert.Equal(visible ? 1 : 0, search.TotalCount);
        Assert.Equal(visible ? 1 : 0, search.Items.Count);
        var recommendations = await new RecommendationService(context).GetRecommendationsAsync(
            client.UserId, new TherapistRecommendationRequestDto());
        Assert.Equal(visible ? 1 : 0, recommendations.Count);

        var reviews = new ReviewService(context, Mock.Of<IBusinessNotificationService>());
        Assert.Equal(visible ? 1 : 0, (await reviews.GetPublicReviewsAsync(6)).Count);
        var memberships = new MembershipService(context, null!, null!,
            Mock.Of<IIntegrationEventPublisher>(), Mock.Of<IOutboxWriter>());
        var appointments = new AppointmentService(context, Mock.Of<IPaymentService>(),
            Mock.Of<IMembershipService>(), new ApplicationMetrics(),
            Mock.Of<IIntegrationEventPublisher>(), Mock.Of<IOutboxWriter>());
        if (visible)
        {
            Assert.Equal(therapist.Id, (await service.GetByIdAsync(therapist.Id, null)).Id);
            Assert.Equal(1, (await reviews.GetTherapistRatingAsync(therapist.Id)).TotalReviews);
            await reviews.GetTherapistReviewsAsync(therapist.Id, new ReviewFilterDto());
            await service.GetAvailabilitiesAsync(therapist.Id);
            await service.GetUnavailableDatesAsync(therapist.Id, 1, 10, null, null);
            await memberships.GetPlansForTherapistAsync(therapist.Id);
            await appointments.GetOccupiedSlotsAsync(therapist.Id, DateTime.UtcNow);
        }
        else
        {
            await Assert.ThrowsAsync<NotFoundException>(() => service.GetByIdAsync(therapist.Id, client.UserId));
            await Assert.ThrowsAsync<NotFoundException>(() => reviews.GetTherapistRatingAsync(therapist.Id));
            await Assert.ThrowsAsync<NotFoundException>(() => reviews.GetTherapistReviewsAsync(therapist.Id, new ReviewFilterDto()));
            await Assert.ThrowsAsync<NotFoundException>(() => service.GetAvailabilitiesAsync(therapist.Id));
            await Assert.ThrowsAsync<NotFoundException>(() => service.GetUnavailableDatesAsync(therapist.Id, 1, 10, null, null));
            await Assert.ThrowsAsync<NotFoundException>(() => memberships.GetPlansForTherapistAsync(therapist.Id));
            await Assert.ThrowsAsync<NotFoundException>(() => appointments.GetOccupiedSlotsAsync(therapist.Id, DateTime.UtcNow));
        }
    }

    [Theory]
    [InlineData(true, 4.5, 2)]
    [InlineData(false, 0, 0)]
    public async Task PublicRatings_UseOnlyApprovedNotDeletedReviews(bool hasApproved, double average, int count)
    {
        await using var context = CreateContext();
        var (therapist, client) = await SeedAsync(context);
        if (hasApproved)
        {
            AddReview(context, therapist, client, 5, true);
            AddReview(context, therapist, client, 4, true);
        }
        await context.SaveChangesAsync();
        var recommender = new RecommendationService(context);
        var before = Assert.Single(await recommender.GetRecommendationsAsync(client.UserId, new TherapistRecommendationRequestDto()));
        AddReview(context, therapist, client, 1, false);
        var inconsistent = AddReview(context, therapist, client, 1, true);
        inconsistent.ModerationStatus = ReviewModerationStatus.Hidden;
        var unapproved = AddReview(context, therapist, client, 1, false);
        unapproved.ModerationStatus = ReviewModerationStatus.Approved;
        AddReview(context, therapist, client, 1, true).IsDeleted = true;
        await context.SaveChangesAsync();

        var service = CreateService(context);
        var all = Assert.Single((await service.GetAllAsync()).Items);
        var filtered = Assert.Single((await service.FilterAsync(new TherapistFilterDto { SortByRating = true })).Items);
        var searched = Assert.Single((await service.SearchAsync(new SearchTherapistsDto
        {
            SortBy = "rating", SortDirection = "desc", PageNumber = 1, PageSize = 10
        })).Items);
        foreach (var item in new[] { all, filtered, searched })
        {
            Assert.Equal(average, item.AverageRating);
            Assert.Equal(count, item.TotalReviews);
        }
        var details = await service.GetByIdAsync(therapist.Id, null);
        Assert.Equal(average, details.AverageRating);
        Assert.Equal(count, details.TotalReviews);
        var recommendation = Assert.Single(await recommender.GetRecommendationsAsync(client.UserId, new TherapistRecommendationRequestDto()));
        Assert.Equal((decimal)average, recommendation.AverageRating);
        Assert.Equal(count, recommendation.ReviewCount);
        Assert.Equal(before.Score, recommendation.Score);
        Assert.Equal(before.Reasons.Select(x => x.AwardedPoints), recommendation.Reasons.Select(x => x.AwardedPoints));
        var reviews = new ReviewService(context, Mock.Of<IBusinessNotificationService>());
        var rating = await reviews.GetTherapistRatingAsync(therapist.Id);
        Assert.Equal(average, rating.AverageRating);
        Assert.Equal(count, rating.TotalReviews);
        Assert.Equal(count, (await reviews.GetTherapistReviewsAsync(therapist.Id, new ReviewFilterDto())).TotalCount);
        Assert.Equal(count, (await reviews.GetPublicReviewsAsync(6)).Count);
        var minRating = await service.SearchAsync(new SearchTherapistsDto { MinRating = 4.4, PageSize = 10 });
        Assert.Equal(hasApproved ? 1 : 0, minRating.TotalCount);
        Assert.Empty((await service.SearchAsync(new SearchTherapistsDto { MinRating = 4.6, PageSize = 10 })).Items);
    }

    [Fact]
    public async Task SearchAsync_AppliesVisibilityAndFiltersBeforeSortingAndPagination()
    {
        await using var context = CreateContext();
        var first = (await SeedAsync(context)).Therapist;
        var second = (await SeedAsync(context)).Therapist;
        var third = (await SeedAsync(context)).Therapist;
        var hidden = (await SeedAsync(context)).Therapist;
        first.HourlyRate = 50m;
        second.HourlyRate = 60m;
        third.HourlyRate = 70m;
        hidden.HourlyRate = 55m;
        hidden.User.Settings!.ShowProfilePublicly = false;
        await context.SaveChangesAsync();
        var service = CreateService(context);

        var result = await service.SearchAsync(new SearchTherapistsDto
        {
            MinPrice = 40m, MaxPrice = 80m, Specialization = "therapy",
            SortBy = "price", SortDirection = "asc", PageNumber = 2, PageSize = 1
        });

        Assert.Equal(3, result.TotalCount);
        Assert.Equal(3, result.TotalPages);
        Assert.Equal(second.Id, Assert.Single(result.Items).Id);
        Assert.True(result.HasPreviousPage);
        Assert.True(result.HasNextPage);
        var filtered = await service.FilterAsync(new TherapistFilterDto { MinPrice = 55m, MaxPrice = 65m });
        Assert.Equal(second.Id, Assert.Single(filtered.Items).Id);
    }

    [Fact]
    public void PublicVisibility_TranslatesToSqlWithoutConnectingToDatabase()
    {
        using var context = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlServer("Server=localhost;Database=VisibilityTranslationOnly;Integrated Security=True;TrustServerCertificate=True").Options);
        var sql = context.Therapists.Where(TherapistVisibility.PubliclyVisible).ToQueryString();
        foreach (var field in new[] { "IsDeleted", "VerificationStatus", "IsActive", "IsBlocked", "ShowProfilePublicly" })
        {
            Assert.Contains(field, sql);
        }
    }

    private static ApplicationDbContext CreateContext() => new(
        new DbContextOptionsBuilder<ApplicationDbContext>().UseInMemoryDatabase($"visibility-{Guid.NewGuid():N}").Options);

    private static TherapistService CreateService(ApplicationDbContext context) => new(context,
        Mock.Of<IWebHostEnvironment>(), Mock.Of<IGeocodingService>(), Mock.Of<ISecurityAuditService>(),
        Mock.Of<ITherapistClientAccessService>(), Options.Create(new UploadSettings()));

    private static async Task<(Therapist Therapist, Client Client)> SeedAsync(ApplicationDbContext context)
    {
        var therapist = new Therapist
        {
            User = new ApplicationUser
            {
                FirstName = "Public", LastName = "Therapist", IsActive = true,
                Settings = new UserSettings { ShowProfilePublicly = true }
            },
            VerificationStatus = TherapistVerificationStatus.Approved, Biography = "Biography",
            Specialization = "Psychotherapy", Education = "Education", HourlyRate = 50m,
            PricePerSession = 50m, OffersOnline = true
        };
        var client = new Client { User = new ApplicationUser { FirstName = "Test", LastName = "Client", IsActive = true } };
        context.Therapists.Add(therapist);
        context.Clients.Add(client);
        await context.SaveChangesAsync();
        return (therapist, client);
    }

    private static Review AddReview(ApplicationDbContext context, Therapist therapist, Client client, int rating, bool approved)
    {
        var review = new Review
        {
            TherapistId = therapist.Id, ClientId = client.Id, Rating = rating, IsApproved = approved,
            ModerationStatus = approved ? ReviewModerationStatus.Approved : ReviewModerationStatus.Pending,
            Comment = "Visibility test review"
        };
        context.Reviews.Add(review);
        return review;
    }
}
