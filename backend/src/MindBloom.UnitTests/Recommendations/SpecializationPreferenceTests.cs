using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.ClientOnboarding.DTOs;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Recommendations;
using MindBloom.Infrastructure.Services;
using MindBloom.Shared.Constants;

namespace MindBloom.UnitTests.Recommendations;

public sealed class SpecializationPreferenceTests
{
    [Theory]
    [InlineData("{}", 2, 15, 32.5)]
    [InlineData("{\"preferredSpecializationIds\":null}", 2, 15, 32.5)]
    [InlineData("{\"preferredSpecializationIds\":[]}", 1, 10, 27.5)]
    [InlineData("{\"preferredSpecializationIds\":[22]}", 1, 15, 32.5)]
    public async Task StoredAndExplicitPreferences_HaveDistinctSemanticsAndChangeActualRanking(
        string json, int firstId, decimal specializationPoints, decimal total)
    {
        await using var db = Context();
        var client = await Seed(db);
        var request = JsonSerializer.Deserialize<TherapistRecommendationRequestDto>(json,
            new JsonSerializerOptions(JsonSerializerDefaults.Web))!;
        var results = await new RecommendationService(db).GetRecommendationsAsync(client.UserId, request);
        Assert.Equal(2, results.Count);
        Assert.Equal(firstId, results[0].TherapistId);
        Assert.Equal(specializationPoints, Points(results[0]));
        Assert.Equal(total, results[0].Score);
        Assert.Equal(15m, results[0].Reasons.Single(x => x.Criterion == "Specialization").MaximumPoints);
        Assert.Equal(results[0].Reasons.Where(x => x.Criterion != "Specialization").Select(x => (x.Criterion, x.AwardedPoints)).OrderBy(x=>x.Criterion),
            results[1].Reasons.Where(x => x.Criterion != "Specialization").Select(x => (x.Criterion, x.AwardedPoints)).OrderBy(x=>x.Criterion));
        Assert.Equal(request.PreferredSpecializationIds?.Count == 0 ? 0m : 15m, results[0].Score - results[1].Score);
    }

    [Theory]
    [InlineData("none", 10)]
    [InlineData("inactive", 10)]
    [InlineData("deleted", 10)]
    [InlineData("multiple", 15)]
    public async Task StoredPreferenceLifecycle_PreservesNeutralBehavior(string state, decimal points)
    {
        await using var db = Context(); var client = await Seed(db);
        if (state == "none") db.ClientSpecializations.RemoveRange(client.PreferredSpecializations);
        if (state == "inactive") (await db.TherapistSpecializations.FindAsync(11))!.IsActive = false;
        if (state == "deleted") (await db.TherapistSpecializations.FindAsync(11))!.IsDeleted = true;
        if (state == "multiple") client.PreferredSpecializations.Add(new() { TherapistSpecializationId = 22 });
        await db.SaveChangesAsync();
        var results = await new RecommendationService(db).GetRecommendationsAsync(client.UserId, new());
        Assert.All(results, x => Assert.Equal(points, Points(x)));
    }

    [Fact]
    public async Task TherapistWithoutSpecialization_DoesNotReceiveMatchingPoints()
    {
        await using var db = Context(); var client = await Seed(db);
        (await db.Therapists.FindAsync(2))!.SpecializationId = null;
        await db.SaveChangesAsync();
        var results = await new RecommendationService(db).GetRecommendationsAsync(client.UserId, new());
        Assert.All(results, x => Assert.Equal(0m, Points(x)));
    }

    [Theory]
    [InlineData("unknown")]
    [InlineData("inactive")]
    [InlineData("deleted")]
    [InlineData("nonpositive")]
    public async Task OnboardingRejectsInvalidSelectionWithoutPartialSave(string invalid)
    {
        await using var db = Context(); var client = await Seed(db);
        if (invalid == "inactive") (await db.TherapistSpecializations.FindAsync(22))!.IsActive = false;
        if (invalid == "deleted") (await db.TherapistSpecializations.FindAsync(22))!.IsDeleted = true;
        await db.SaveChangesAsync();
        var request = Request([11, invalid == "unknown" ? 999 : invalid == "nonpositive" ? 0 : 22]);
        request.PreferredLanguages = ["German"];
        await Assert.ThrowsAsync<BadRequestException>(() => new ClientOnboardingService(db).SaveAsync(client.UserId, request));
        Assert.Equal("English", client.PreferredLanguages);
        Assert.Equal(11, Assert.Single(await db.ClientSpecializations.ToListAsync()).TherapistSpecializationId);
    }

    [Fact]
    public async Task Onboarding_ReplacesDeduplicatesPreservesAndExplicitlyClearsSelection()
    {
        await using var db = Context(); var client = await Seed(db);
        var service = new ClientOnboardingService(db);
        await service.SaveAsync(client.UserId, Request([11,22,22]));
        Assert.Equal(new[] {11,22}, (await service.GetAsync(client.UserId)).PreferredSpecializationIds);
        await service.SaveAsync(client.UserId, Request([22]));
        await service.SaveAsync(client.UserId, Request([22]));
        Assert.Equal(22, Assert.Single(await db.ClientSpecializations.ToListAsync()).TherapistSpecializationId);
        await service.SaveAsync(client.UserId, Request(null));
        Assert.Equal(new[] {22}, (await service.GetAsync(client.UserId)).PreferredSpecializationIds);
        Assert.Equal("English", client.PreferredLanguages);
        Assert.Equal("Anxiety", client.AssessmentFocusAreas);
        Assert.Equal("1", client.PreferredDays);
        await service.SaveAsync(client.UserId, Request([]));
        Assert.Empty((await service.GetAsync(client.UserId)).PreferredSpecializationIds);
    }

    [Theory]
    [InlineData(0)] [InlineData(999)] [InlineData(22)]
    public async Task ExplicitInvalidOrInactiveRecommendationIds_ReturnBusinessError(int id)
    {
        await using var db = Context(); var client = await Seed(db);
        (await db.TherapistSpecializations.FindAsync(22))!.IsActive = false; await db.SaveChangesAsync();
        await Assert.ThrowsAsync<BadRequestException>(() => new RecommendationService(db)
            .GetRecommendationsAsync(client.UserId, new() { PreferredSpecializationIds = [id] }));
    }

    private static decimal Points(TherapistRecommendationDto value) => value.Reasons.Single(x => x.Criterion == "Specialization").AwardedPoints;
    private static SaveClientOnboardingDto Request(List<int>? ids) => new() {
        PreferredSpecializationIds = ids, PreferredLanguages = ["English"], AssessmentFocusAreas = ["Anxiety"],
        PreferredDays = [DayOfWeek.Monday], AcceptSensitiveDataProcessing = true,
        SensitiveDataProcessingVersion = ConsentDocumentConstants.SensitiveDataProcessingVersion
    };
    private static ApplicationDbContext Context() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase($"specialization-{Guid.NewGuid():N}").Options);
    private static ApplicationUser User(string name) => new() { FirstName=name, LastName="Test", UserName=name,
        Email=$"{name}@test.local", IsActive=true };
    private static async Task<Client> Seed(ApplicationDbContext db)
    {
        db.TherapistSpecializations.AddRange(new() {Id=11,Name="Anxiety"}, new() {Id=22,Name="Trauma"});
        var client = new Client { User=User("Client"), PreferredLanguages="English",
            PreferredSpecializations=[new() {TherapistSpecializationId=11}] };
        db.Clients.Add(client);
        // The matching therapist deliberately has the larger ID, defeating the neutral tie-breaker.
        db.Therapists.AddRange(new Therapist {Id=1,User=User("B"),SpecializationId=22,Specialization="Trauma",Biography="Generic",Languages="English",HourlyRate=50,VerificationStatus=TherapistVerificationStatus.Approved},
            new Therapist {Id=2,User=User("A"),SpecializationId=11,Specialization="Anxiety",Biography="Generic",Languages="English",HourlyRate=50,VerificationStatus=TherapistVerificationStatus.Approved});
        await db.SaveChangesAsync(); return client;
    }
}
