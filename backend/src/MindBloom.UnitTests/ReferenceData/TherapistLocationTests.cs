using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Persistence.Seed;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.ReferenceData;

public sealed class TherapistLocationTests
{
    private static ApplicationDbContext Context() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase($"locations-{Guid.NewGuid():N}").Options);

    [Fact]
    public async Task Crud_NormalizesValidatesDuplicatesAndKeepsReferencedLocations()
    {
        await using var db = Context();
        var service = new ReferenceDataService(db);
        var first = await service.SaveTherapistLocationAsync(null, new() { Name = " Town ", Country = " Country ", Region = " Region " });
        Assert.Equal("Town, Region, Country", first.DisplayName);
        await Assert.ThrowsAsync<BusinessException>(() => service.SaveTherapistLocationAsync(null, new() { Name = "town", Country = "country", Region = "region" }));
        var other = await service.SaveTherapistLocationAsync(null, new() { Name = "Town", Country = "Country", Region = "Other region" });
        var therapist = new Therapist { LocationId = first.Id, Biography = "Test", Specialization = "Test", City = "Town", Country = "Country", Address = "Keep address" };
        db.Therapists.Add(therapist); await db.SaveChangesAsync();
        await service.SaveTherapistLocationAsync(first.Id, new() { Name = "Renamed", Country = "Country", Region = "Region" });
        Assert.Equal("Renamed", therapist.City); Assert.Equal("Keep address", therapist.Address);
        await service.DeleteTherapistLocationAsync(first.Id);
        Assert.False((await service.GetTherapistLocationByIdAsync(first.Id)).IsActive);
        Assert.Equal(first.Id, therapist.LocationId);
        await service.DeleteTherapistLocationAsync(other.Id);
        await Assert.ThrowsAsync<NotFoundException>(() => service.GetTherapistLocationByIdAsync(other.Id));
    }

    [Theory]
    [InlineData("", "Country", "")]
    [InlineData("Town", "", "")]
    [InlineData(" ", "Country", "")]
    public async Task InvalidNames_ReturnBadRequest(string name, string country, string region)
    {
        await using var db = Context();
        await Assert.ThrowsAsync<BadRequestException>(() => new ReferenceDataService(db).SaveTherapistLocationAsync(null, new() { Name = name, Country = country, Region = region }));
    }

    [Fact]
    public async Task LengthLimitsAndMissingIds_AreBusinessErrors()
    {
        await using var db = Context(); var service = new ReferenceDataService(db);
        foreach (var request in new[] { new SaveTherapistLocationDto { Name = new('a',101), Country = "C" }, new() { Name = "T", Country = new('a',101) }, new() { Name = "T", Country = "C", Region = new('a',101) } })
            await Assert.ThrowsAsync<BadRequestException>(() => service.SaveTherapistLocationAsync(null, request));
        await Assert.ThrowsAsync<NotFoundException>(() => service.SaveTherapistLocationAsync(99, new() { Name = "T", Country = "C" }));
        await Assert.ThrowsAsync<NotFoundException>(() => service.DeleteTherapistLocationAsync(99));
    }

    [Fact]
    public async Task Lists_AreBoundedSortedAndFilterActiveBeforeCounting()
    {
        await using var db = Context();
        db.TherapistLocations.AddRange(Enumerable.Range(1,120).Select(i => new TherapistLocation { Name = $"Town {i:000}", Country = "C", IsActive = i % 2 == 0 }));
        await db.SaveChangesAsync(); var service = new ReferenceDataService(db);
        var page = await service.GetTherapistLocationsAsync(new() { PageNumber = 2, PageSize = 10, IsActive = true });
        Assert.Equal(60, page.TotalCount); Assert.Equal(6, page.TotalPages); Assert.Equal("Town 022", page.Items[0].Name);
        Assert.Equal(MindBloom.Application.Common.Pagination.PaginationDefaults.MaximumPageSize,
            (await service.GetTherapistLocationsAsync(new() { PageSize = int.MaxValue })).Items.Count);
        Assert.Empty((await service.GetTherapistLocationsAsync(new() { PageNumber = 999 })).Items);
        Assert.Empty((await service.GetTherapistLocationsAsync(new() { PageNumber = int.MaxValue, PageSize = int.MaxValue })).Items);
    }

    [Fact]
    public async Task Seed_IsRepeatableAndDoesNotGuessAmbiguousLocations()
    {
        await using var db = Context();
        var known = new Therapist { Biography = "Test", Specialization = "Test", City = "Sarajevo", Country = "Bosnia and Herzegovina", Location = "Sarajevo", Address = "Preserved" };
        var unknown = new Therapist { Biography = "Test", Specialization = "Test", City = "Unknown", Country = "Test", Location = "Original text" };
        db.Therapists.AddRange(known, unknown); await db.SaveChangesAsync();
        await TherapistLocationSeed.SeedAsync(db); await TherapistLocationSeed.SeedAsync(db);
        Assert.Equal(2, await db.TherapistLocations.CountAsync()); Assert.NotNull(known.LocationId); Assert.Null(unknown.LocationId);
        Assert.Equal("Preserved", known.Address); Assert.Equal("Original text", unknown.Location);
        known.LocationId = null;
        db.TherapistLocations.Add(new() { Name = "Sarajevo", Country = "Bosnia and Herzegovina", Region = "Another region" }); await db.SaveChangesAsync();
        await TherapistLocationSeed.SeedAsync(db); Assert.Null(known.LocationId);
    }
}
