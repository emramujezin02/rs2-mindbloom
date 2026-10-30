using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.BusinessRules;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using Moq;

namespace MindBloom.UnitTests.Reviews;

public sealed class PublicReviewDemographicsTests
{
    [Theory]
    [InlineData("2000-10-29", "2026-10-30", 26)]
    [InlineData("2000-10-30", "2026-10-30", 26)]
    [InlineData("2000-10-31", "2026-10-30", 25)]
    [InlineData("2000-02-29", "2025-02-28", 24)]
    [InlineData("2000-02-29", "2025-03-01", 25)]
    [InlineData("2000-02-29", "2024-02-29", 24)]
    [InlineData(null, "2026-10-30", null)]
    [InlineData("0001-01-01", "2026-10-30", null)]
    [InlineData("2027-01-01", "2026-10-30", null)]
    [InlineData("1800-01-01", "2026-10-30", null)]
    public void Age_UsesCalendarBirthdayAndRejectsInvalidDates(string? birth, string today, int? expected)
        => Assert.Equal(expected, PublicReviewDemographics.CalculateAge(birth == null ? null : DateTime.Parse(birth), DateTime.Parse(today)));

    [Theory]
    [InlineData(" female ", "Female")]
    [InlineData("MALE", "Male")]
    [InlineData("Other", "Other")]
    [InlineData(null, null)]
    [InlineData("unknown", null)]
    public void Gender_UsesOnlyExistingRegisteredValues(string? input, string? expected)
        => Assert.Equal(expected, PublicReviewDemographics.NormalizeGender(input));

    [Theory]
    [InlineData(true, true, 30, true)]
    [InlineData(false, true, 30, false)]
    [InlineData(true, false, 30, false)]
    [InlineData(true, true, 17, false)]
    [InlineData(true, true, 18, true)]
    [InlineData(true, true, -1, false)]
    [InlineData(true, true, 2000, false)]
    public async Task PublicProjection_RequiresConsentPublicProfileAndAdult(bool consent, bool publicProfile, int age, bool visible)
    {
        await using var db = Context();
        var review = await Seed(db);
        review.ShareAuthorDemographics = consent;
        review.Client.User.Settings!.ShowProfilePublicly = publicProfile;
        review.Client.User.DateOfBirth = age == 2000 ? default : new DateTime(2026, 10, 30).AddYears(-age);
        await db.SaveChangesAsync();
        var dto = Assert.Single(await Service(db).GetPublicReviewsAsync(6));
        Assert.Equal(visible ? age : null, dto.AuthorAge);
        Assert.Equal(visible ? "Female" : null, dto.AuthorGender);
        Assert.Equal("A. M.", dto.ClientInitials);
        Assert.Equal(review.Comment, dto.Comment);
        Assert.Equal(5, dto.Rating);
        var properties = typeof(PublicReviewDto).GetProperties().Select(x => x.Name).ToList();
        Assert.DoesNotContain("DateOfBirth", properties);
        Assert.DoesNotContain("Email", properties);
        Assert.DoesNotContain("PhoneNumber", properties);
        Assert.DoesNotContain("ClientId", properties);
    }

    [Fact]
    public async Task ConsentWithdrawal_PreservesApprovalAndCannotChangeAnotherAuthorsReview()
    {
        await using var db = Context();
        var review = await Seed(db);
        Assert.False(review.ShareAuthorDemographics);
        var service = Service(db);
        var request = new UpdateReviewDto { Rating = 5, Comment = review.Comment, ShareAuthorDemographics = true };
        await service.UpdateAsync(review.Client.UserId, review.Id, request);
        Assert.NotNull(Assert.Single(await service.GetPublicReviewsAsync(6)).AuthorAge);
        request.ShareAuthorDemographics = false;
        await service.UpdateAsync(review.Client.UserId, review.Id, request);
        Assert.Null(Assert.Single(await service.GetPublicReviewsAsync(6)).AuthorAge);
        Assert.True(review.IsApproved);
        Assert.Equal(ReviewModerationStatus.Approved, review.ModerationStatus);
        request.ShareAuthorDemographics = true;
        var otherClient = new Client { User = new ApplicationUser { FirstName = "Other", LastName = "Client" } };
        db.Add(otherClient);
        await db.SaveChangesAsync();
        await Assert.ThrowsAnyAsync<Exception>(() => service.UpdateAsync(otherClient.UserId, review.Id, request));
        Assert.False(review.ShareAuthorDemographics);
        request.Comment = "Changed review content.";
        await service.UpdateAsync(review.Client.UserId, review.Id, request);
        Assert.False(review.IsApproved);
        Assert.Empty(await service.GetPublicReviewsAsync(6));
    }

    [Fact]
    public async Task Create_WithConsentStillRequiresModerationAndOwnListReturnsPreference()
    {
        await using var db = Context();
        var existing = await Seed(db);
        var appointment = new Appointment { Client = existing.Client, Therapist = existing.Therapist, Status = AppointmentStatus.Completed };
        db.Add(appointment); await db.SaveChangesAsync();
        var service = Service(db);
        await service.CreateAsync(existing.Client.UserId, new CreateReviewDto {
            AppointmentId = appointment.Id, Rating = 4, Comment = "Another helpful session.", ShareAuthorDemographics = true });
        var created = await db.Reviews.SingleAsync(x => x.AppointmentId == appointment.Id);
        Assert.True(created.ShareAuthorDemographics);
        Assert.False(created.IsApproved);
        Assert.Equal(ReviewModerationStatus.Pending, created.ModerationStatus);
        Assert.DoesNotContain(await service.GetPublicReviewsAsync(6), x => x.Id == created.Id);
        var ownReviews = await service.GetMyReviewsAsync(existing.Client.UserId, 1, 10);
        Assert.True(ownReviews.Items.Single(x => x.Id == created.Id).ShareAuthorDemographics);
    }

    private static ApplicationDbContext Context() => new(new DbContextOptionsBuilder<ApplicationDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static ReviewService Service(ApplicationDbContext db) => new(db, Mock.Of<IBusinessNotificationService>(), new Clock());
    private sealed class Clock : TimeProvider { public override DateTimeOffset GetUtcNow() => new(2026, 10, 30, 12, 0, 0, TimeSpan.Zero); }
    private static async Task<Review> Seed(ApplicationDbContext db)
    {
        var review = new Review {
            Client = new Client { User = new ApplicationUser { FirstName = "Anna", LastName = "Mason", Gender = "Female", DateOfBirth = new(1990, 1, 1), Settings = new UserSettings { ShowProfilePublicly = true } } },
            Therapist = new Therapist { Biography = "Test", Specialization = "Test", VerificationStatus = TherapistVerificationStatus.Approved, User = new ApplicationUser { FirstName = "Test", LastName = "Therapist", IsActive = true } },
            Rating = 5, Comment = "A helpful session.", IsApproved = true, ModerationStatus = ReviewModerationStatus.Approved
        };
        db.Add(review); await db.SaveChangesAsync(); return review;
    }
}
