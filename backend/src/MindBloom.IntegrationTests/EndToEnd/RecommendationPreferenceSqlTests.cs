using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.Infrastructure.Recommendations;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class RecommendationPreferenceSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Fact]
    public async Task ReadmeDemo_SeedAndLegacyPreferencesProduceIdenticalRecommendationScores()
    {
        // This factory owns a disposable SQL container and database, never the working database.
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var users = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var roles = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole<int>>>();
        await ApplicationDbSeeder.SeedAsync(db, users, roles);
        var client = await db.Clients.Include(x => x.User).SingleAsync(x => x.User.Email == "mobile@mindbloom.com");
        Assert.Equal("Bosnian|English", client.PreferredLanguages);
        Assert.Equal("1,3,5", client.PreferredDays);
        Assert.Equal("Anxiety|sleep|stress", client.AssessmentFocusAreas);
        var service = new RecommendationService(db);
        var canonical = await service.GetRecommendationsAsync(client.UserId, new());
        var aminaId = await db.Therapists.Where(x => x.User.Email == "amina@mindbloom.com").Select(x => x.Id).SingleAsync();
        var amina = Assert.Single(canonical, x => x.TherapistId == aminaId);
        Assert.Equal(10m, amina.Reasons.Single(x => x.Criterion == "Initial assessment").AwardedPoints);
        Assert.Equal(15m, amina.Reasons.Single(x => x.Criterion == "Preferred schedule").AwardedPoints);
        Assert.Equal(100m, amina.Reasons.Sum(x => x.MaximumPoints));

        var specializationCount=await db.TherapistSpecializations.CountAsync();
        Therapist Legacy(string text)=>new() {User=new ApplicationUser {FirstName="Legacy",LastName="Test",UserName=$"legacy-{Guid.NewGuid():N}",IsActive=true},
            Specialization=text,Biography="Legacy profile",VerificationStatus=TherapistVerificationStatus.Pending};
        var unknown=Legacy("Unmapped legacy specialization");
        var exact=Legacy(" Anxiety Disorders ");
        db.AddRange(unknown,exact);

        client.PreferredLanguages = "Bosnian, English";
        client.PreferredDays = "Monday, Wednesday, Friday";
        client.AssessmentFocusAreas = "Anxiety, stress, sleep";
        await db.SaveChangesAsync();
        // Re-running the actual seeder must not overwrite existing clients' preferences.
        await ApplicationDbSeeder.SeedAsync(db, users, roles);
        Assert.Equal(specializationCount,await db.TherapistSpecializations.CountAsync());
        await db.Entry(unknown).ReloadAsync(); await db.Entry(exact).ReloadAsync();
        Assert.Null(unknown.SpecializationId); Assert.Equal("Unmapped legacy specialization",unknown.Specialization);
        Assert.Equal(await db.TherapistSpecializations.Where(x=>x.Name=="Anxiety Disorders").Select(x=>x.Id).SingleAsync(),exact.SpecializationId);
        await db.Entry(client).ReloadAsync();
        Assert.Equal("Bosnian, English", client.PreferredLanguages);
        Assert.Equal("Monday, Wednesday, Friday", client.PreferredDays);
        Assert.Equal("Anxiety, stress, sleep", client.AssessmentFocusAreas);
        var legacy = await service.GetRecommendationsAsync(client.UserId, new());
        Assert.Equal(canonical.Select(x => (x.TherapistId, x.Score)), legacy.Select(x => (x.TherapistId, x.Score)));
        foreach (var result in canonical)
            Assert.Equal(result.Reasons.Select(x => (x.Criterion, x.AwardedPoints, x.MaximumPoints)),
                legacy.Single(x => x.TherapistId == result.TherapistId).Reasons.Select(x => (x.Criterion, x.AwardedPoints, x.MaximumPoints)));
        var onboarding = await new ClientOnboardingService(db).GetAsync(client.UserId);
        Assert.Equal(new[] { "Bosnian", "English" }, onboarding.PreferredLanguages);
        Assert.Equal(new[] { DayOfWeek.Monday, DayOfWeek.Wednesday, DayOfWeek.Friday }, onboarding.PreferredDays);
        Assert.Equal(3, onboarding.AssessmentFocusAreas.Count);
    }
}
