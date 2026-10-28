using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.ClientOnboarding.DTOs;
using MindBloom.Application.Features.Users.DTOs;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Recommendations;

public sealed class PreferenceFormatApiTests
{
    [Fact]
    public async Task OnboardingSave_RecommendationsAndReadbackUseTheSamePreferenceFormat()
    {
        using var factory = new MindBloomIntegrationTestFactory();
        const int userId = 81701;
        await factory.SeedActiveUserAsync(userId, RoleConstants.Client, "preference-api@test.local", "Test1234!");
        await factory.SeedClientProfileAsync(userId);
        int approachId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var approach = new TherapyApproach { Name = "Test approach", Description = "Test", IsActive = true };
            db.TherapyApproaches.Add(approach);
            foreach (var language in new[] { "Bosnian", "English", "German" })
                db.Therapists.Add(new Therapist { User = new ApplicationUser { UserName = language,
                    FirstName = language, LastName = "Test", Email = $"{language}@test.local", IsActive = true },
                    VerificationStatus = TherapistVerificationStatus.Approved,
                    Specialization = "Anxiety", Biography = "Anxiety and stress", Education = "Test",
                    Languages = language, OffersOnline = true });
            await db.SaveChangesAsync();
            approachId = approach.Id;
        }
        using var http = factory.CreateAuthenticatedClient(userId, RoleConstants.Client);
        var response = await http.PutAsJsonAsync("/api/client-onboarding", new SaveClientOnboardingDto {
            PreferredLanguages = ["Bosnian", "English"], AssessmentFocusAreas = ["Anxiety", "Stress"],
            PreferredDays = [DayOfWeek.Monday, DayOfWeek.Wednesday, DayOfWeek.Friday],
            PreferredTherapyApproachIds = [approachId], AcceptSensitiveDataProcessing = true,
            SensitiveDataProcessingVersion = ConsentDocumentConstants.SensitiveDataProcessingVersion
        });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var stored = await db.Clients.SingleAsync(x => x.UserId == userId);
            Assert.Equal("Bosnian|English", stored.PreferredLanguages);
            Assert.Equal("Anxiety|Stress", stored.AssessmentFocusAreas);
            Assert.Equal("1,3,5", stored.PreferredDays);
        }
        var read = await http.GetFromJsonAsync<ClientOnboardingDto>("/api/client-onboarding");
        Assert.Equal(new[] { "Bosnian", "English" }, read!.PreferredLanguages);
        var recommendations = await http.PostAsJsonAsync("/api/recommendations/therapists", new TherapistRecommendationRequestDto());
        Assert.Equal(HttpStatusCode.OK, recommendations.StatusCode);
        var results = await recommendations.Content.ReadFromJsonAsync<List<TherapistRecommendationDto>>();
        Assert.Equal(new[] { "Bosnian Test", "English Test" }, results!.Select(x => x.FullName).Order());
        var profile = await http.GetFromJsonAsync<UserProfileDto>("/api/users/me");
        Assert.Equal(new[] { "Bosnian", "English" }, profile!.PreferredLanguages);
        var update = await http.PutAsJsonAsync("/api/users/me", new UpdateUserProfileDto {
            FirstName = "Test", LastName = "Client", DateOfBirth = new DateTime(1990,1,1),
            PreferredLanguages = [" English ", "Bosnian", "bosnian"]
        });
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Assert.Equal("Bosnian|English", (await db.Clients.SingleAsync(x => x.UserId == userId)).PreferredLanguages);
        }
        Assert.Equal(new[] { "Bosnian", "English" },
            (await http.GetFromJsonAsync<ClientOnboardingDto>("/api/client-onboarding"))!.PreferredLanguages);
    }
}
