using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Features.ClientOnboarding.DTOs;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.Infrastructure.Recommendations;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.Shared.Constants;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class SpecializationPreferenceSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Fact]
    public async Task OnboardingAndTherapistProfiles_PersistReferencesAndRerankRealSqlRecommendations()
    {
        using var scope=factory.Services.CreateScope();
        var db=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var specs=new[] {new TherapistSpecialization {Name="SQL group A"},new TherapistSpecialization {Name="SQL group B"}};
        var approach=new TherapyApproach {Name="SQL approach",Description="Test",IsActive=true};
        var client=new Client {User=User("Client")};
        var userB=User("B"); var userA=User("A");
        db.AddRange(specs); db.AddRange(approach,client,userB,userA); await db.SaveChangesAsync();
        var therapists=scope.ServiceProvider.GetRequiredService<ITherapistService>();
        var b=await therapists.CreateAsync(userB.Id,Create(specs[1].Id));
        var a=await therapists.CreateAsync(userA.Id,Create(specs[0].Id));
        foreach(var value in new[] {a,b}) {
            var entity=await db.Therapists.SingleAsync(x=>x.Id==value.Id);
            entity.VerificationStatus=TherapistVerificationStatus.Approved;
            await therapists.UpdateProfileAsync(entity.UserId,new UpdateTherapistProfileDto {
                SpecializationId=entity.SpecializationId,Biography="Identical profile",HourlyRate=50,Location="City",
                Country="Country",City="City",Address="Preserved address",OffersOnline=true,
                Languages=["English"],TherapyApproachIds=[approach.Id],WorksWithChildren=true
            });
        }
        var onboarding=new ClientOnboardingService(db);
        SaveClientOnboardingDto Request(int id)=>new() { PreferredSpecializationIds=[id,id],
            PreferredLanguages=["English"],AssessmentFocusAreas=["Sleep"],PreferredDays=[DayOfWeek.Monday],
            PreferredTherapyApproachIds=[approach.Id],AcceptSensitiveDataProcessing=true,
            SensitiveDataProcessingVersion=ConsentDocumentConstants.SensitiveDataProcessingVersion };
        await onboarding.SaveAsync(client.UserId,Request(specs[0].Id));
        db.ChangeTracker.Clear();
        var loaded=await onboarding.GetAsync(client.UserId);
        Assert.Equal(new[] {specs[0].Id},loaded.PreferredSpecializationIds);
        Assert.Single(await db.ClientSpecializations.Where(x=>x.ClientId==client.Id).ToListAsync());
        var recommender=new RecommendationService(db);
        var first=await recommender.GetRecommendationsAsync(client.UserId,new());
        Assert.Equal(a.Id,first[0].TherapistId); Assert.Equal(15m,Points(first[0])); Assert.Equal(0m,Points(first[1]));
        Assert.Equal(15m,first[0].Score-first[1].Score);
        Assert.Equal(first[0].Reasons.Where(x=>x.Criterion!="Specialization").Select(x=>(x.Criterion,x.AwardedPoints)).OrderBy(x=>x.Criterion),
            first[1].Reasons.Where(x=>x.Criterion!="Specialization").Select(x=>(x.Criterion,x.AwardedPoints)).OrderBy(x=>x.Criterion));
        var explicitResult=await recommender.GetRecommendationsAsync(client.UserId,new() {PreferredSpecializationIds=[specs[1].Id]});
        Assert.Equal(b.Id,explicitResult[0].TherapistId);
        var empty=await recommender.GetRecommendationsAsync(client.UserId,new() {PreferredSpecializationIds=[]});
        Assert.All(empty,x=>Assert.Equal(10m,Points(x)));
        await onboarding.SaveAsync(client.UserId,Request(specs[1].Id));
        Assert.Equal(b.Id,(await recommender.GetRecommendationsAsync(client.UserId,new()))[0].TherapistId);
        Assert.Equal("English",(await db.Clients.AsNoTracking().SingleAsync(x=>x.Id==client.Id)).PreferredLanguages);
        Assert.Equal(specs[0].Id,(await therapists.GetProfileAsync(userA.Id)).SpecializationId);
        Assert.Equal("Preserved address",(await therapists.GetProfileAsync(userA.Id)).Address);
        Assert.True((await therapists.GetProfileAsync(userA.Id)).WorksWithChildren);
        var existing=await db.ClientSpecializations.AsNoTracking().SingleAsync(x=>x.ClientId==client.Id);
        db.ClientSpecializations.Add(new() {ClientId=client.Id,TherapistSpecializationId=existing.TherapistSpecializationId});
        await Assert.ThrowsAsync<DbUpdateException>(()=>db.SaveChangesAsync());
        db.ChangeTracker.Clear();
        db.ClientSpecializations.Add(new() {ClientId=client.Id,TherapistSpecializationId=int.MaxValue});
        await Assert.ThrowsAsync<DbUpdateException>(()=>db.SaveChangesAsync());
        db.ChangeTracker.Clear();
    }

    [Fact]
    public async Task Migration_PreservesClientsAndLegacyProfilesAndOnlyBackfillsUnambiguousNames()
    {
        using var scope=factory.Services.CreateScope();
        var baseDb=scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var migrationIds=baseDb.GetService<IMigrationsAssembly>().Migrations.Keys;
        var latest=migrationIds.Single(x=>x.EndsWith("_AddClientSpecializationPreferences"));
        var previous=migrationIds.Where(x=>string.CompareOrdinal(x,latest)<0).Max()!;
        foreach(var populated in new[] {false,true}) {
            var connection=new SqlConnectionStringBuilder(baseDb.Database.GetConnectionString()) {InitialCatalog=$"MindBloomSpecMigration_{Guid.NewGuid():N}"};
            await using var db=new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>().UseSqlServer(connection.ConnectionString).Options);
            List<(int Id,string Text,int? Expected)> expected=[];
            int clientId=0,usersBefore=0;
            try {
                if(populated) {
                    await db.GetService<IMigrator>().MigrateAsync(previous);
                    var exact=new TherapistSpecialization {Name="Exact match"};
                    var inactive=new TherapistSpecialization {Name="Inactive match",IsActive=false};
                    db.AddRange(exact,inactive,new TherapistSpecialization {Name="Ambiguous"},new TherapistSpecialization {Name=" Ambiguous"},new TherapistSpecialization {Name="Deleted match",IsDeleted=true});
                    var client=new Client {User=User("Legacy client"),PreferredLanguages="Bosnian|English",PreferredDays="1,3,5",AssessmentFocusAreas="Anxiety|Stress"};
                    db.Add(client); await db.SaveChangesAsync(); clientId=client.Id;
                    foreach(var (text,id) in new (string,int?)[] {(" Exact match ",exact.Id),("Inactive match",inactive.Id),("Ambiguous",null),("Unknown original",null),("Deleted match",null)}) {
                        var therapist=new Therapist {User=User("Legacy therapist"),Biography="Preserved",Specialization=text,Address="Preserved address",Country="Country",City="City"};
                        db.Add(therapist); await db.SaveChangesAsync(); expected.Add((therapist.Id,text,id));
                    }
                    var linked=new Therapist {User=User("Already linked"),Biography="Preserved",Specialization="Original legacy text",
                        SpecializationId=inactive.Id,Address="Preserved address",Country="Country",City="City"};
                    db.Add(linked); await db.SaveChangesAsync(); expected.Add((linked.Id,linked.Specialization,inactive.Id));
                    usersBefore=await db.Users.CountAsync();
                }
                await db.Database.MigrateAsync(); db.ChangeTracker.Clear();
                Assert.Contains(latest,await db.Database.GetAppliedMigrationsAsync());
                Assert.Empty(await db.ClientSpecializations.ToListAsync());
                if(populated) {
                    Assert.Equal(usersBefore,await db.Users.CountAsync()); Assert.Equal(expected.Count,await db.Therapists.CountAsync());
                    foreach(var item in expected) {
                        var therapist=await db.Therapists.SingleAsync(x=>x.Id==item.Id);
                        Assert.Equal(item.Text,therapist.Specialization); Assert.Equal(item.Expected,therapist.SpecializationId);
                        Assert.Equal("Preserved address",therapist.Address);
                    }
                    var client=await db.Clients.SingleAsync(x=>x.Id==clientId);
                    Assert.Equal("Bosnian|English",client.PreferredLanguages); Assert.Equal("1,3,5",client.PreferredDays); Assert.Equal("Anxiety|Stress",client.AssessmentFocusAreas);
                }
            } finally {
                Assert.StartsWith("MindBloomSpecMigration_",connection.InitialCatalog);
                await db.Database.EnsureDeletedAsync(); // Only this uniquely named disposable database.
            }
        }
    }
    private static decimal Points(TherapistRecommendationDto x)=>x.Reasons.Single(r=>r.Criterion=="Specialization").AwardedPoints;
    private static ApplicationUser User(string name)=>new() {UserName=$"spec-{Guid.NewGuid():N}",FirstName=name,LastName="Test",IsActive=true};
    private static CreateTherapistDto Create(int id)=>new() {SpecializationId=id,Specialization="Ignored",Biography="Identical profile",HourlyRate=50,Country="Country",City="City",Address="Preserved address",OffersOnline=true};
}
