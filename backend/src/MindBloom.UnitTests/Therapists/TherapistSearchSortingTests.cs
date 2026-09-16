using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Moq;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Security.Interfaces;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Therapists;

public sealed class TherapistSearchSortingTests
{
    [Fact]
    public async Task SearchAsync_WhenPriceAscending_ReturnsLowestPriceFirst()
    {
        await using var context =
            CreateContext();

        await SeedTherapistsAsync(context);

        var service =
            CreateService(context);

        var result =
            await service.SearchAsync(
                CreateRequest(
                    "price",
                    "asc"));

        Assert.Equal(
            ["Low Price", "Middle Price", "High Price"],
            result.Items.Select(x => x.FullName).ToList());
    }

    [Fact]
    public async Task SearchAsync_WhenPriceDescending_ReturnsHighestPriceFirst()
    {
        await using var context =
            CreateContext();

        await SeedTherapistsAsync(context);

        var service =
            CreateService(context);

        var result =
            await service.SearchAsync(
                CreateRequest(
                    "price",
                    "desc"));

        Assert.Equal(
            ["High Price", "Middle Price", "Low Price"],
            result.Items.Select(x => x.FullName).ToList());
    }

    [Fact]
    public async Task SearchAsync_WhenRatingAscending_ReturnsLowestRatingFirst()
    {
        await using var context =
            CreateContext();

        await SeedTherapistsAsync(context);

        var service =
            CreateService(context);

        var result =
            await service.SearchAsync(
                CreateRequest(
                    "rating",
                    "asc"));

        Assert.Equal(
            ["Low Price", "Middle Price", "High Price"],
            result.Items.Select(x => x.FullName).ToList());
    }

    [Fact]
    public async Task SearchAsync_WhenRatingDescending_ReturnsHighestRatingFirst()
    {
        await using var context =
            CreateContext();

        await SeedTherapistsAsync(context);

        var service =
            CreateService(context);

        var result =
            await service.SearchAsync(
                CreateRequest(
                    "rating",
                    "desc"));

        Assert.Equal(
            ["High Price", "Middle Price", "Low Price"],
            result.Items.Select(x => x.FullName).ToList());
    }

    [Fact]
    public async Task SearchAsync_WhenSortValuesTie_UsesTherapistIdTieBreaker()
    {
        await using var context =
            CreateContext();

        await SeedTherapistsAsync(
            context,
            useTiedPrices: true);

        var service =
            CreateService(context);

        var result =
            await service.SearchAsync(
                CreateRequest(
                    "price",
                    "asc"));

        Assert.Equal(
            result.Items.OrderBy(x => x.Id).Select(x => x.Id),
            result.Items.Select(x => x.Id));
    }

    private static SearchTherapistsDto
        CreateRequest(
            string sortBy,
            string sortDirection)
    {
        return new SearchTherapistsDto
        {
            SortBy =
                sortBy,

            SortDirection =
                sortDirection,

            PageNumber =
                1,

            PageSize =
                10
        };
    }

    private static async Task SeedTherapistsAsync(
        ApplicationDbContext context,
        bool useTiedPrices = false)
    {
        var therapists =
            new[]
            {
                CreateTherapist(
                    "Low",
                    "Price",
                    useTiedPrices ? 100m : 50m,
                    2),

                CreateTherapist(
                    "Middle",
                    "Price",
                    100m,
                    4),

                CreateTherapist(
                    "High",
                    "Price",
                    useTiedPrices ? 100m : 150m,
                    5)
            };

        context.Therapists.AddRange(therapists);

        await context.SaveChangesAsync();
    }

    private static Therapist CreateTherapist(
        string firstName,
        string lastName,
        decimal hourlyRate,
        int rating)
    {
        var therapist =
            new Therapist
            {
                User =
                    new ApplicationUser
                    {
                        UserName =
                            $"{firstName}.{lastName}@test.local",

                        Email =
                            $"{firstName}.{lastName}@test.local",

                        FirstName =
                            firstName,

                        LastName =
                            lastName,

                        IsActive =
                            true,

                        CreatedAtUtc =
                            DateTime.UtcNow
                    },

                Biography =
                    "Sorting test therapist",

                Specialization =
                    "Psychotherapy",

                VerificationStatus =
                    TherapistVerificationStatus.Approved,

                HourlyRate =
                    hourlyRate,

                PricePerSession =
                    hourlyRate,

                ExperienceYears =
                    rating,

                Country =
                    "Bosnia and Herzegovina",

                City =
                    "Sarajevo",

                Address =
                    "Sorting test address",

                OffersOnline =
                    true,

                OffersInPerson =
                    true,

                Education =
                    "Sorting test education"
            };

        therapist.Reviews.Add(
            new Review
            {
                Rating =
                    rating,

                IsApproved =
                    true,

                Comment =
                    "Sorting test review"
            });

        return therapist;
    }

    private static TherapistService CreateService(
        ApplicationDbContext context)
    {
        var environment =
            new Mock<IWebHostEnvironment>();

        var geocodingService =
            new Mock<IGeocodingService>();

        var securityAuditService =
            new Mock<ISecurityAuditService>();

        var therapistClientAccessService =
            new Mock<ITherapistClientAccessService>();

        var uploadOptions =
            Options.Create(
                new UploadSettings());

        return new TherapistService(
            context,
            environment.Object,
            geocodingService.Object,
            securityAuditService.Object,
            therapistClientAccessService.Object,
            uploadOptions);
    }

    private static ApplicationDbContext CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"therapist-search-sorting-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(options);
    }
}
