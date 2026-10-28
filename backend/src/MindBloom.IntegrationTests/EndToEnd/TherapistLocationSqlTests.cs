using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using System.Net;
using System.Net.Http.Json;
using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class TherapistLocationSqlTests(MindBloomEndToEndTestFactory factory) : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Fact]
    public async Task Migration_WorksOnEmptyAndPopulatedDatabasesWithoutLosingLegacyData()
    {
        using var scope = factory.Services.CreateScope();
        var factoryDb = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var migrations = factoryDb.GetService<IMigrationsAssembly>().Migrations;
        var latest = migrations.Single(x => x.Key.EndsWith("_AddTherapistLocationsAndChildren")).Key;
        var previous = migrations.Keys.Where(x => string.CompareOrdinal(x, latest) < 0).Max()!;
        foreach (var populated in new[] { false, true })
        {
            var builder = new SqlConnectionStringBuilder(factoryDb.Database.GetConnectionString()) { InitialCatalog = $"MindBloomLocationMigration_{Guid.NewGuid():N}" };
            var options = new DbContextOptionsBuilder<ApplicationDbContext>().UseSqlServer(builder.ConnectionString).Options;
            await using var db = new ApplicationDbContext(options);
            try
            {
                if (populated)
                {
                    await db.GetService<IMigrator>().MigrateAsync(previous);
                    await using var legacy = new LegacyContext(options);
                    legacy.Therapists.AddRange(
                        LegacyTherapist("Sarajevo", "Bosnia and Herzegovina", "Sarajevo"),
                        LegacyTherapist("Sarajevo", "Other country", "Sarajevo"),
                        LegacyTherapist("Mostar", "Bosnia and Herzegovina", "Unresolved neighbourhood"),
                        LegacyTherapist("Unknown town", "Bosnia and Herzegovina", "Original location"));
                    await legacy.SaveChangesAsync();
                }
                await db.Database.MigrateAsync();
                Assert.Equal(2, await db.TherapistLocations.CountAsync());
                if (populated)
                {
                    var therapists = await db.Therapists.Include(x => x.User).OrderBy(x => x.Id).ToListAsync();
                    Assert.Equal(4, therapists.Count);
                    Assert.NotNull(therapists[0].LocationId); Assert.All(therapists.Skip(1), x => Assert.Null(x.LocationId));
                    Assert.Equal("Unresolved neighbourhood", therapists[2].Location); Assert.Equal("Original location", therapists[3].Location);
                    Assert.All(therapists, x => { Assert.NotNull(x.User); Assert.Equal("Preserved address", x.Address); Assert.False(x.WorksWithChildren); });
                    await TherapistLocationSeed.SeedAsync(db); await TherapistLocationSeed.SeedAsync(db);
                    Assert.Equal(2, await db.TherapistLocations.CountAsync()); Assert.Equal(4, await db.Therapists.CountAsync());
                }
            }
            finally
            {
                Assert.StartsWith("MindBloomLocationMigration_", builder.InitialCatalog);
                await db.Database.EnsureDeletedAsync(); // This test's uniquely named, disposable database only.
            }
        }
    }

    [Fact]
    public async Task Search_CombinesAdvancedFiltersAndPagesOnSqlServer()
    {
        int locationId, approachId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var location = new TherapistLocation { Name = "SQL town", Country = "C" };
            var approach = new TherapyApproach { Name = "SQL approach" }; db.AddRange(location, approach); await db.SaveChangesAsync();
            locationId = location.Id; approachId = approach.Id;
            for (var i = 0; i < 4; i++)
            {
                var therapist = LegacyTherapist("SQL town", "C", "SQL town");
                therapist.LocationId = locationId; therapist.ExperienceYears = 3 + i; therapist.OffersOnline = true; therapist.WorksWithChildren = i < 3;
                therapist.TherapyApproaches.Add(new() { TherapyApproachId = approachId }); db.Therapists.Add(therapist);
            }
            await db.SaveChangesAsync();
        }
        using var client = factory.CreateClient();
        var query = $"/api/Therapists/search?locationId={locationId}&therapyApproachId={approachId}&minExperienceYears=3&maxExperienceYears=5&offersOnline=true&worksWithChildren=true&pageSize=2";
        var first = await client.GetFromJsonAsync<PagedResponse<TherapistResponseDto>>(query);
        var second = await client.GetFromJsonAsync<PagedResponse<TherapistResponseDto>>(query + "&pageNumber=2");
        Assert.NotNull(first); Assert.NotNull(second); Assert.Equal(3, first.TotalCount); Assert.Equal(2, first.Items.Count); Assert.Single(second.Items);
        Assert.Empty(first.Items.Select(x => x.Id).Intersect(second.Items.Select(x => x.Id)));
        Assert.All(first.Items.Concat(second.Items), x => { Assert.Equal(locationId, x.LocationId); Assert.True(x.WorksWithChildren); });
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync(query.Replace("minExperienceYears=3", "minExperienceYears=6"))).StatusCode);
    }

    private static Therapist LegacyTherapist(string city, string country, string location) => new() {
        User = new ApplicationUser { FirstName = "Test", LastName = "Therapist", UserName = $"location-{Guid.NewGuid():N}", IsActive = true },
        Biography = "Test", Specialization = "Test", Country = country, City = city, Location = location,
        Address = "Preserved address", VerificationStatus = TherapistVerificationStatus.Approved
    };

    private sealed class LegacyContext(DbContextOptions<ApplicationDbContext> options) : ApplicationDbContext(options)
    {
        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);
            builder.Entity<Therapist>().Ignore(x => x.LocationReference).Ignore(x => x.LocationId).Ignore(x => x.WorksWithChildren);
            builder.Ignore<TherapistLocation>();
        }
    }
}
