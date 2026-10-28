using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;

namespace MindBloom.UnitTests.Therapists;

public sealed partial class PublicTherapistVisibilityTests
{
    [Fact]
    public async Task ProfileUpdate_SavesLocationAndChildrenWithoutChangingAddressOrVerification()
    {
        await using var db = CreateContext(); var (therapist, _) = await SeedAsync(db);
        var location = new TherapistLocation { Name = "Selected town", Country = "Selected country" };
        var approach = new TherapyApproach { Name = "Approach" }; db.AddRange(location, approach); await db.SaveChangesAsync();
        var request = new UpdateTherapistProfileDto { LocationId = location.Id, WorksWithChildren = true, Biography = "Updated", Specialization = "Psychotherapy",
            ExperienceYears = 5, HourlyRate = 50, Location = "Legacy location", Country = "Legacy country", City = "Legacy city", Address = "Keep address",
            OffersOnline = true, Languages = ["Bosnian"], TherapyApproachIds = [approach.Id] };
        var service = CreateService(db); await service.UpdateProfileAsync(therapist.UserId, request);
        Assert.Equal(location.Id, therapist.LocationId); Assert.Equal("Selected town", therapist.City); Assert.Equal("Selected country", therapist.Country);
        Assert.Equal("Keep address", therapist.Address); Assert.True(therapist.WorksWithChildren);
        Assert.Equal(MindBloom.Domain.Enums.TherapistVerificationStatus.Approved, therapist.VerificationStatus);
        location.IsActive = false; await db.SaveChangesAsync();
        await service.UpdateProfileAsync(therapist.UserId, request); // existing inactive selection is retained
        request.LocationId = location.Id + 99;
        await Assert.ThrowsAsync<BadRequestException>(() => service.UpdateProfileAsync(therapist.UserId, request));
    }

    [Theory]
    [InlineData(null, null, true)]
    [InlineData(0, 2, false)]
    [InlineData(3, 5, true)]
    [InlineData(6, 10, false)]
    [InlineData(11, 70, false)]
    public async Task ExperienceRanges_HaveInclusiveBoundaries(int? minimum, int? maximum, bool matches)
    {
        await using var db = CreateContext(); var (therapist, _) = await SeedAsync(db);
        therapist.ExperienceYears = 5; await db.SaveChangesAsync();
        Assert.Equal(matches ? 1 : 0, (await CreateService(db).SearchAsync(new() { MinExperienceYears = minimum, MaxExperienceYears = maximum })).TotalCount);
    }

    [Fact]
    public async Task CombinedFilters_IntersectBeforePagingAndKeepApprovedReviewRules()
    {
        await using var db = CreateContext(); var (therapist, client) = await SeedAsync(db);
        var location = new TherapistLocation { Name = "Town", Country = "C" }; db.TherapistLocations.Add(location);
        var approach = new TherapyApproach { Name = "Approach" }; db.TherapyApproaches.Add(approach); await db.SaveChangesAsync();
        therapist.LocationId = location.Id; therapist.ExperienceYears = 5; therapist.WorksWithChildren = true;
        db.TherapistTherapyApproaches.Add(new() { TherapistId = therapist.Id, TherapyApproachId = approach.Id });
        AddReview(db, therapist, client, 5, true); AddReview(db, therapist, client, 4, true); AddReview(db, therapist, client, 1, false);
        await db.SaveChangesAsync(); var service = CreateService(db);
        var request = new SearchTherapistsDto { LocationId = location.Id, TherapyApproachId = approach.Id, MinExperienceYears = 3, MaxExperienceYears = 5, OffersOnline = true, WorksWithChildren = true, PageSize = 1 };
        var page = await service.SearchAsync(request); var item = Assert.Single(page.Items);
        Assert.Equal(1, page.TotalCount); Assert.Equal(4.5, item.AverageRating); Assert.Equal(2, item.TotalReviews);
        Assert.True(item.WorksWithChildren); Assert.Equal(location.Id, item.LocationId);
        request.PageNumber = 2; Assert.Empty((await service.SearchAsync(request)).Items);
        request.PageNumber = int.MaxValue; request.PageSize = int.MaxValue;
        Assert.Empty((await service.SearchAsync(request)).Items);
        request.PageNumber = 1; request.LocationId = location.Id + 1; Assert.Empty((await service.SearchAsync(request)).Items);
        therapist.WorksWithChildren = false; await db.SaveChangesAsync(); request.LocationId = location.Id;
        Assert.Empty((await service.SearchAsync(request)).Items);
        request.WorksWithChildren = false; request.OffersOnline = false; therapist.OffersOnline = false; await db.SaveChangesAsync();
        Assert.Single((await service.SearchAsync(request)).Items); // unchecked means unrestricted
        therapist.User.IsBlocked = true; await db.SaveChangesAsync(); Assert.Empty((await service.SearchAsync(request)).Items);
    }

    [Theory]
    [InlineData(-1, null, null)]
    [InlineData(null, -1, 5)]
    [InlineData(null, 6, 5)]
    [InlineData(null, 0, 71)]
    public async Task InvalidAdvancedParameters_ReturnBadRequest(int? location, int? minimum, int? maximum)
    {
        await using var db = CreateContext();
        await Assert.ThrowsAsync<BadRequestException>(() => CreateService(db).SearchAsync(new() { LocationId = location, MinExperienceYears = minimum, MaxExperienceYears = maximum }));
    }
}
