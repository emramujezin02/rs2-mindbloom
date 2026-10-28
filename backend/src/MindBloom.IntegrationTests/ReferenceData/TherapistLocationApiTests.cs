using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.ReferenceData;

public sealed class TherapistLocationApiTests
{
    [Theory]
    [InlineData(null, HttpStatusCode.Unauthorized)]
    [InlineData(RoleConstants.Client, HttpStatusCode.Forbidden)]
    [InlineData(RoleConstants.Therapist, HttpStatusCode.Forbidden)]
    public async Task LocationMutations_RequireAdmin(string? role, HttpStatusCode expected)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        if (role != null) await factory.SeedActiveUserAsync(9201, role, "location-access@test.local", "TestingPassword123!");
        using var client = role == null ? factory.CreateClient() : factory.CreateAuthenticatedClient(9201, role);
        Assert.Equal(expected, (await client.PostAsJsonAsync("/api/reference-data/locations", new { name = "Town", country = "Country" })).StatusCode);
        Assert.Equal(expected, (await client.PutAsJsonAsync("/api/reference-data/locations/1", new { name = "Town", country = "Country" })).StatusCode);
        Assert.Equal(expected, (await client.DeleteAsync("/api/reference-data/locations/1")).StatusCode);
        Assert.Equal(expected, (await client.GetAsync("/api/reference-data/locations")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/api/reference-data/locations/active")).StatusCode);
    }

    [Fact]
    public async Task AdminCrud_ValidatesDuplicatesPagesAndDeactivatesReferencedLocation()
    {
        using var factory = new MindBloomIntegrationTestFactory();
        await factory.SeedActiveUserAsync(9202, RoleConstants.Admin, "location-admin@test.local", "TestingPassword123!");
        using var admin = factory.CreateAuthenticatedClient(9202, RoleConstants.Admin);
        var request = new SaveTherapistLocationDto { Name = "Town", Country = "C", Region = "R" };
        var created = await admin.PostAsJsonAsync("/api/reference-data/locations", request); Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var location = await created.Content.ReadFromJsonAsync<TherapistLocationResponseDto>(); Assert.NotNull(location);
        Assert.Equal(HttpStatusCode.Conflict, (await admin.PostAsJsonAsync("/api/reference-data/locations", request)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await admin.PostAsJsonAsync("/api/reference-data/locations", new { name = "", country = "C" })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await admin.GetAsync("/api/reference-data/locations/999999")).StatusCode);
        request.Name = "Edited"; Assert.Equal(HttpStatusCode.OK, (await admin.PutAsJsonAsync($"/api/reference-data/locations/{location.Id}", request)).StatusCode);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.Therapists.Add(new Therapist { UserId = 9202, Biography = "Test", Specialization = "Test", LocationId = location.Id });
            db.TherapistLocations.AddRange(Enumerable.Range(1, 105).Select(i => new TherapistLocation { Name = $"Other {i:000}", Country = "C" }));
            await db.SaveChangesAsync();
        }
        var page = await admin.GetFromJsonAsync<PagedResponse<TherapistLocationResponseDto>>("/api/reference-data/locations?pageSize=9999");
        Assert.NotNull(page); Assert.Equal(MindBloom.Application.Common.Pagination.PaginationDefaults.MaximumPageSize, page.Items.Count); Assert.Equal(106, page.TotalCount);
        Assert.Equal(HttpStatusCode.NoContent, (await admin.DeleteAsync($"/api/reference-data/locations/{location.Id}")).StatusCode);
        Assert.False((await admin.GetFromJsonAsync<TherapistLocationResponseDto>($"/api/reference-data/locations/{location.Id}"))!.IsActive);
        using var anonymous = factory.CreateClient();
        var active = await anonymous.GetFromJsonAsync<PagedResponse<TherapistLocationResponseDto>>("/api/reference-data/locations/active?search=Edited&isActive=false");
        Assert.NotNull(active); Assert.Empty(active.Items);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task Registration_UsesSelectedLocationAndPreservesPendingVerification(bool validLocation)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        await factory.EnsureRoleExistsAsync(RoleConstants.Therapist);
        int id;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var location = new TherapistLocation { Name = "Selected city", Country = "Selected country" };
            db.TherapistLocations.Add(location); await db.SaveChangesAsync(); id = location.Id;
        }
        using var client = factory.CreateClient();
        var request = new RegisterTherapistRequestDto {
            FirstName = "Test", LastName = "Therapist", Email = "location-registration@test.local", Username = "location-registration",
            Password = "TestingPassword123!", DateOfBirth = new(1990,1,1), Gender = "Other", Biography = "Test", Specialization = "Test", HourlyRate = 50,
            Country = "Legacy country", City = "Legacy city", Address = "Keep address", OffersOnline = true,
            LocationId = validLocation ? id : 999999, WorksWithChildren = true,
            AcceptPrivacyPolicy = true, PrivacyPolicyVersion = ConsentDocumentConstants.PrivacyPolicyVersion,
            AcceptTermsOfService = true, TermsOfServiceVersion = ConsentDocumentConstants.TermsOfServiceVersion
        };
        var response = await client.PostAsJsonAsync("/api/Auth/register-therapist", request);
        Assert.Equal(validLocation ? HttpStatusCode.Created : HttpStatusCode.BadRequest, response.StatusCode);
        using var checkScope = factory.Services.CreateScope(); var context = checkScope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        if (!validLocation) { Assert.False(await context.Users.AnyAsync(x => x.Email == request.Email)); return; }
        var therapist = await context.Therapists.SingleAsync();
        Assert.Equal(id, therapist.LocationId); Assert.True(therapist.WorksWithChildren);
        Assert.Equal("Selected city", therapist.City); Assert.Equal("Selected country", therapist.Country); Assert.Equal("Keep address", therapist.Address);
        Assert.Equal(TherapistVerificationStatus.Pending, therapist.VerificationStatus);
    }
}
