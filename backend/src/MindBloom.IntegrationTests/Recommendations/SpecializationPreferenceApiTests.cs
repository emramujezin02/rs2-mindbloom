using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.ClientOnboarding.DTOs;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.IntegrationTests.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.Recommendations;

public sealed class SpecializationPreferenceApiTests
{
    [Theory]
    [InlineData("omitted")]
    [InlineData("null")]
    [InlineData("empty")]
    [InlineData("duplicates")]
    [InlineData("multiple")]
    [InlineData("unknown")]
    [InlineData("inactive")]
    [InlineData("deleted")]
    public async Task Onboarding_HonorsFieldPresenceAndRejectsInvalidIdsAtomically(string choice)
    {
        using var factory = new MindBloomIntegrationTestFactory();
        const int userId = 91901;
        await factory.SeedActiveUserAsync(userId, RoleConstants.Client, "specialization-client@test.local", "Test1234!");
        await factory.SeedClientProfileAsync(userId);
        int firstId, secondId, approachId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var first = new TherapistSpecialization { Name="First" };
            var second = new TherapistSpecialization { Name="Second", IsActive=choice!="inactive", IsDeleted=choice=="deleted" };
            var approach = new TherapyApproach { Name="Approach", Description="Test", IsActive=true };
            db.AddRange(first,second,approach); await db.SaveChangesAsync();
            firstId=first.Id; secondId=second.Id; approachId=approach.Id;
            var client = await db.Clients.SingleAsync(x=>x.UserId==userId);
            client.PreferredLanguages="English";
            db.ClientSpecializations.Add(new() {ClientId=client.Id,TherapistSpecializationId=firstId});
            await db.SaveChangesAsync();
        }
        using var http = factory.CreateAuthenticatedClient(userId,RoleConstants.Client);
        var body = new JsonObject {
            ["assessmentFocusAreas"]=new JsonArray("Anxiety"), ["preferredLanguages"]=new JsonArray("English"),
            ["preferredDays"]=new JsonArray(1), ["preferredTherapyApproachIds"]=new JsonArray(approachId),
            ["acceptSensitiveDataProcessing"]=true, ["sensitiveDataProcessingVersion"]=ConsentDocumentConstants.SensitiveDataProcessingVersion
        };
        if(choice!="omitted") body["preferredSpecializationIds"]=choice switch {
            "null"=>null, "empty"=>new JsonArray(), "unknown"=>new JsonArray(firstId,99999),
            "multiple"=>new JsonArray(firstId,secondId),
            _=>new JsonArray(secondId,secondId)
        };
        var response = await http.PutAsJsonAsync("/api/client-onboarding",body);
        var invalid=choice is "unknown" or "inactive" or "deleted";
        Assert.Equal(invalid ? HttpStatusCode.BadRequest : HttpStatusCode.OK,response.StatusCode);
        if(!invalid) Assert.Equal(HttpStatusCode.OK,(await http.PutAsJsonAsync("/api/client-onboarding",body)).StatusCode);
        var saved=await http.GetFromJsonAsync<ClientOnboardingDto>("/api/client-onboarding");
        Assert.Equal(choice=="empty" ? Array.Empty<int>() : choice=="multiple" ? new[] {firstId,secondId} : new[] {choice=="duplicates" ? secondId:firstId},saved!.PreferredSpecializationIds);
        Assert.Equal(new[] {"English"},saved.PreferredLanguages);
        using var check=factory.Services.CreateScope();
        var context=check.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(choice=="empty" ? 0:choice=="multiple" ? 2:1,await context.ClientSpecializations.CountAsync());
        if(invalid) Assert.Null((await context.Clients.SingleAsync(x=>x.UserId==userId)).AssessmentFocusAreas);
    }

    [Theory]
    [InlineData("valid")]
    [InlineData("missing")]
    [InlineData("unknown")]
    [InlineData("inactive")]
    [InlineData("deleted")]
    public async Task Registration_RequiresActiveIdAndStoresReferenceNameAndPendingState(string state)
    {
        using var factory=new MindBloomIntegrationTestFactory();
        await factory.EnsureRoleExistsAsync(RoleConstants.Therapist);
        int id, locationId;
        using(var scope=factory.Services.CreateScope()) {
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var spec=new TherapistSpecialization {Name="Chosen reference",IsActive=state!="inactive",IsDeleted=state=="deleted"};
            var location=new TherapistLocation {Name="Chosen city",Country="Country"};
            db.AddRange(spec,location); await db.SaveChangesAsync(); id=spec.Id; locationId=location.Id;
        }
        var request=new RegisterTherapistRequestDto {
            SpecializationId=state=="missing" ? null:state=="unknown" ? 99999:id, Specialization="Untrusted text",
            FirstName="Test",LastName="Therapist",Username="specialization-registration",Email="specialization-registration@test.local",
            Password="Testing123!",DateOfBirth=new(1990,1,1),Gender="Other",Biography="Test",HourlyRate=50,
            Country="Legacy",City="Legacy",Address="Preserved address",OffersOnline=true,LocationId=locationId,WorksWithChildren=true,
            AcceptPrivacyPolicy=true,PrivacyPolicyVersion=ConsentDocumentConstants.PrivacyPolicyVersion,
            AcceptTermsOfService=true,TermsOfServiceVersion=ConsentDocumentConstants.TermsOfServiceVersion
        };
        using var http=factory.CreateClient();
        var response=await http.PostAsJsonAsync("/api/auth/register-therapist",request);
        Assert.Equal(state=="valid" ? HttpStatusCode.Created:HttpStatusCode.BadRequest,response.StatusCode);
        using var check=factory.Services.CreateScope(); var dbCheck=check.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        if(state!="valid") { Assert.False(await dbCheck.Users.AnyAsync(x=>x.Email==request.Email)); return; }
        var therapist=await dbCheck.Therapists.SingleAsync();
        Assert.Equal(id,therapist.SpecializationId); Assert.Equal("Chosen reference",therapist.Specialization);
        Assert.Equal(locationId,therapist.LocationId); Assert.True(therapist.WorksWithChildren);
        Assert.Equal("Preserved address",therapist.Address); Assert.Equal(TherapistVerificationStatus.Pending,therapist.VerificationStatus);
    }

    [Fact]
    public async Task RecommendationHttpBinding_DistinguishesOmittedNullAndEmptyPreferences()
    {
        using var factory=new MindBloomIntegrationTestFactory(); const int userId=91902;
        await factory.SeedActiveUserAsync(userId,RoleConstants.Client,"specialization-ranking@test.local","Test1234!");
        await factory.SeedClientProfileAsync(userId);
        int specId;
        using(var scope=factory.Services.CreateScope()) {
            var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var spec=new TherapistSpecialization {Name="Matching"}; db.Add(spec); await db.SaveChangesAsync(); specId=spec.Id;
            var client=await db.Clients.SingleAsync(x=>x.UserId==userId);
            db.ClientSpecializations.Add(new() {ClientId=client.Id,TherapistSpecializationId=spec.Id});
            db.Therapists.Add(new() {User=new ApplicationUser {FirstName="Test",LastName="Therapist",IsActive=true},
                SpecializationId=spec.Id,Specialization=spec.Name,Biography="Test",VerificationStatus=TherapistVerificationStatus.Approved});
            await db.SaveChangesAsync();
        }
        using var http=factory.CreateAuthenticatedClient(userId,RoleConstants.Client);
        foreach(var (body,points) in new[] {("{}",15m),("{\"preferredSpecializationIds\":null}",15m),("{\"preferredSpecializationIds\":[]}",10m)}) {
            var response=await http.PostAsync("/api/recommendations/therapists",new StringContent(body,System.Text.Encoding.UTF8,"application/json"));
            Assert.Equal(HttpStatusCode.OK,response.StatusCode);
            var result=Assert.Single((await response.Content.ReadFromJsonAsync<List<TherapistRecommendationDto>>())!);
            Assert.Equal(points,result.Reasons.Single(x=>x.Criterion=="Specialization").AwardedPoints);
        }
        Assert.True(specId>0);
    }
}
