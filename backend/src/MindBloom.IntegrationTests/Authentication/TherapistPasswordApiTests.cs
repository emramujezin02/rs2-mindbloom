using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Authentication;

public sealed class TherapistPasswordApiTests
{
    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task TooLongPassword_Returns400WithoutCreatingUserOrTherapist(bool unicode)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        using var client = factory.CreateClient();
        var email = $"therapist-{Guid.NewGuid():N}@test.local";
        var request = new RegisterTherapistRequestDto
        {
            FirstName = "Test", LastName = "Therapist", Email = email,
            Username = $"therapist_{Guid.NewGuid():N}",
            Password = unicode ? "Ab1!😀" + new string('a', 123) : "Ab1!" + new string('a', 125),
            DateOfBirth = new DateTime(1990, 1, 1), Gender = "Female",
            Specialization = "Psychotherapy", Biography = "Test biography", HourlyRate = 50,
            ExperienceYears = 5, Country = "Test", City = "Test", Address = "Test", OffersOnline = true,
            AcceptPrivacyPolicy = true, PrivacyPolicyVersion = ConsentDocumentConstants.PrivacyPolicyVersion,
            AcceptTermsOfService = true, TermsOfServiceVersion = ConsentDocumentConstants.TermsOfServiceVersion
        };
        using var scope = factory.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var userCount = await context.Users.CountAsync();
        var therapistCount = await context.Therapists.CountAsync();
        var response = await client.PostAsJsonAsync("/api/Auth/register-therapist", request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("Password may contain at most 128 characters.", body);
        Assert.DoesNotContain(request.Password, body);
        Assert.Equal(userCount, await context.Users.CountAsync());
        Assert.Equal(therapistCount, await context.Therapists.CountAsync());
        Assert.False(await context.Users.AnyAsync(x => x.Email == email));
    }
}
