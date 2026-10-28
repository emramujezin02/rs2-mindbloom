using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.ClientOnboarding.DTOs;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Recommendations;
using MindBloom.Infrastructure.Services;
using MindBloom.Shared.Constants;

namespace MindBloom.UnitTests.Recommendations;

public sealed class StoredPreferenceFlowTests
{
    [Theory]
    [InlineData("Bosnian|English")]
    [InlineData("Bosnian, English")]
    [InlineData(" Bosnian || bosnian, English , ")]
    public async Task LanguageFilter_MatchesEitherLanguageWithoutAdmittingUnrelatedLanguage(string languages)
    {
        await using var db = Context();
        var client = new Client { User = User("client"), PreferredLanguages = languages };
        var bosnian = Therapist("bosnian", "Bosnian");
        var english = Therapist("english", "English");
        var german = Therapist("german", "German");
        db.Clients.Add(client);
        db.Therapists.AddRange(bosnian, english, german);
        await db.SaveChangesAsync();

        var results = await new RecommendationService(db).GetRecommendationsAsync(client.UserId, new());

        Assert.Equal(new[] { bosnian.Id, english.Id }.Order(), results.Select(x => x.TherapistId).Order());
    }

    [Theory]
    [InlineData("Monday, Wednesday, Friday", "Anxiety, Stress")]
    [InlineData("1,3,5", "Anxiety|Stress")]
    public async Task StoredFormats_ProduceExistingScoresAndRequestOverridePriority(string days, string focus)
    {
        await using var db = Context();
        var client = new Client { User = User("client"), PreferredDays = days, AssessmentFocusAreas = focus };
        var therapist = Therapist("matching", "English");
        therapist.Biography = "Anxiety and stress support";
        therapist.Availabilities.Add(new() { DayOfWeek = DayOfWeek.Monday });
        therapist.Availabilities.Add(new() { DayOfWeek = DayOfWeek.Friday });
        db.Clients.Add(client); db.Therapists.Add(therapist);
        await db.SaveChangesAsync();
        var service = new RecommendationService(db);

        var result = Assert.Single(await service.GetRecommendationsAsync(client.UserId, new()));
        Assert.Equal(15m, result.Reasons.Single(x => x.Criterion == "Initial assessment").AwardedPoints);
        Assert.Equal(10m, result.Reasons.Single(x => x.Criterion == "Preferred schedule").AwardedPoints);
        var weights = new Dictionary<string, decimal> {
            ["Specialization"] = 15, ["Therapy approach"] = 10, ["Initial assessment"] = 15,
            ["Preferred schedule"] = 15, ["Price"] = 10, ["Experience"] = 10, ["Rating"] = 10,
            ["Availability"] = 10, ["Previous appointments"] = 3, ["Favorite therapist"] = 2
        };
        Assert.Equal(weights.Count, result.Reasons.Count);
        foreach (var reason in result.Reasons) Assert.Equal(weights[reason.Criterion], reason.MaximumPoints);
        var overridden = Assert.Single(await service.GetRecommendationsAsync(client.UserId, new()
        {
            PreferredDays = [DayOfWeek.Tuesday], AssessmentFocusAreas = ["Unmatched"]
        }));
        Assert.Equal(0m, overridden.Reasons.Single(x => x.Criterion == "Initial assessment").AwardedPoints);
        Assert.Equal(0m, overridden.Reasons.Single(x => x.Criterion == "Preferred schedule").AwardedPoints);
    }

    [Fact]
    public async Task Onboarding_ReadsLegacyValuesAndWritesCanonicalValuesOnSaveAndUpdate()
    {
        await using var db = Context();
        var client = new Client { User = User("client"), PreferredLanguages = "Bosnian, English",
            PreferredDays = "Monday, Wednesday, Friday", AssessmentFocusAreas = "Anxiety, Stress" };
        db.Clients.Add(client);
        await db.SaveChangesAsync();
        var service = new ClientOnboardingService(db);
        var read = await service.GetAsync(client.UserId);
        Assert.Equal(new[] { "Bosnian", "English" }, read.PreferredLanguages);
        Assert.Equal(new[] { DayOfWeek.Monday, DayOfWeek.Wednesday, DayOfWeek.Friday }, read.PreferredDays);
        Assert.Equal(new[] { "Anxiety", "Stress" }, read.AssessmentFocusAreas);
        var request = new SaveClientOnboardingDto {
            PreferredLanguages = [" English ", "Bosnian", "bosnian"],
            AssessmentFocusAreas = [" Stress ", "Anxiety", "anxiety"],
            PreferredDays = [DayOfWeek.Friday, DayOfWeek.Monday, DayOfWeek.Monday],
            AcceptSensitiveDataProcessing = true,
            SensitiveDataProcessingVersion = ConsentDocumentConstants.SensitiveDataProcessingVersion
        };
        await service.SaveAsync(client.UserId, request);
        Assert.Equal("Bosnian|English", client.PreferredLanguages);
        Assert.Equal("Anxiety|Stress", client.AssessmentFocusAreas);
        Assert.Equal("1,5", client.PreferredDays);
        request.PreferredLanguages = ["German"];
        await service.SaveAsync(client.UserId, request);
        Assert.Equal("German", client.PreferredLanguages);
        Assert.Equal("German", Assert.Single((await service.GetAsync(client.UserId)).PreferredLanguages));
    }

    private static ApplicationDbContext Context() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase($"preference-flow-{Guid.NewGuid():N}").Options);
    private static ApplicationUser User(string name) => new() { UserName = name, Email = $"{name}@test.local",
        FirstName = name, LastName = "Test", IsActive = true, EmailConfirmed = true };
    private static Therapist Therapist(string name, string languages) => new() { User = User(name),
        VerificationStatus = TherapistVerificationStatus.Approved,
        Biography = "Test", Specialization = "General", Languages = languages, OffersOnline = true };
}
