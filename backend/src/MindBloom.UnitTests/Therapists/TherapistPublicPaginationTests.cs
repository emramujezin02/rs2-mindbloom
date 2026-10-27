using MindBloom.Application.Common.Models;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Therapists;

public sealed partial class PublicTherapistVisibilityTests
{
    public static IEnumerable<object[]> PaginationCases()
    {
        foreach (var filter in new[] { false, true })
        {
            foreach (var values in new[]
            {
                new[] { 1, 1, 1, 1, 1 }, new[] { 2, 10, 2, 10, 10 },
                new[] { 3, 10, 3, 10, 3 }, new[] { 4, 10, 4, 10, 0 },
                new[] { 0, 0, 1, 10, 10 }, new[] { -5, -10, 1, 10, 10 },
                new[] { 1, 999, 1, 50, 23 }, new[] { int.MaxValue, 50, int.MaxValue, 50, 0 }
            })
            {
                yield return new object[] { filter, values[0], values[1], values[2], values[3], values[4] };
            }
        }
    }

    [Theory]
    [MemberData(nameof(PaginationCases))]
    public async Task PublicPagination_NormalizesAndReturnsCorrectMetadata(
        bool filter, int page, int size, int expectedPage, int expectedSize, int expectedCount)
    {
        await using var context = CreateContext();
        var therapists = await SeedManyAsync(context, 23);
        var result = await ReadPageAsync(CreateService(context), filter, page, size);

        Assert.Equal(expectedPage, result.PageNumber);
        Assert.Equal(expectedSize, result.PageSize);
        Assert.Equal(23, result.TotalCount);
        Assert.Equal((int)Math.Ceiling(23d / expectedSize), result.TotalPages);
        Assert.Equal(expectedCount, result.Items.Count);
        Assert.Equal(expectedPage > 1, result.HasPreviousPage);
        Assert.Equal(expectedPage < result.TotalPages, result.HasNextPage);
        var expectedIds = therapists.Skip((int)Math.Min((long)(expectedPage - 1) * expectedSize, int.MaxValue))
            .Take(expectedSize).Select(x => x.Id);
        Assert.Equal(expectedIds, result.Items.Select(x => x.Id));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PublicPagination_DefaultsAndMaximumCannotReturnUnboundedList(bool filter)
    {
        await using var context = CreateContext();
        await SeedManyAsync(context, 61);
        var service = CreateService(context);
        var defaults = filter ? await service.FilterAsync(new TherapistFilterDto()) : await service.GetAllAsync();
        Assert.Equal(1, defaults.PageNumber);
        Assert.Equal(10, defaults.PageSize);
        Assert.Equal(10, defaults.Items.Count);
        var maximum = await ReadPageAsync(service, filter, 1, int.MaxValue);
        Assert.Equal(50, maximum.PageSize);
        Assert.Equal(50, maximum.Items.Count);
        Assert.Equal(61, maximum.TotalCount);
        var second = await ReadPageAsync(service, filter, 2, 50);
        Assert.Equal(11, second.Items.Count);
        Assert.Empty(maximum.Items.Select(x => x.Id).Intersect(second.Items.Select(x => x.Id)));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PublicPagination_EmptyDatabaseReturnsEmptyPage(bool filter)
    {
        await using var context = CreateContext();
        var result = await ReadPageAsync(CreateService(context), filter, 1, 10);
        Assert.Empty(result.Items);
        Assert.Equal(0, result.TotalCount);
        Assert.Equal(0, result.TotalPages);
        Assert.False(result.HasNextPage);
        Assert.False(result.HasPreviousPage);
    }

    [Fact]
    public async Task FilterPagination_CountsFilteredVisibleSetBeforePaging()
    {
        await using var context = CreateContext();
        var therapists = await SeedManyAsync(context, 23);
        therapists[10].User.IsBlocked = true;
        await context.SaveChangesAsync();
        var result = await CreateService(context).FilterAsync(new TherapistFilterDto
        {
            Specialization = "therapy", MinPrice = 10, MaxPrice = 20
        }, 2, 3);
        var expected = therapists.Where(x => x.HourlyRate >= 10 && x.HourlyRate <= 20 && !x.User.IsBlocked).ToList();
        Assert.Equal(expected.Count, result.TotalCount);
        Assert.Equal(expected.Skip(3).Take(3).Select(x => x.Id), result.Items.Select(x => x.Id));
        Assert.Empty((await CreateService(context).FilterAsync(new TherapistFilterDto { Specialization = "missing" })).Items);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task PublicPagination_RatingOrderIsAppliedBeforeTakingFirstPage(bool filter)
    {
        await using var context = CreateContext();
        var (lower, client) = await SeedAsync(context);
        var higher = (await SeedAsync(context)).Therapist;
        AddReview(context, lower, client, 1, true);
        AddReview(context, higher, client, 5, true);
        AddReview(context, higher, client, 4, true);
        AddReview(context, higher, client, 1, false);
        await context.SaveChangesAsync();
        var service = CreateService(context);
        var result = filter
            ? await service.FilterAsync(new TherapistFilterDto { SortByRating = true }, 1, 1)
            : await service.GetAllAsync(1, 1);
        var item = Assert.Single(result.Items);
        Assert.Equal(higher.Id, item.Id);
        Assert.Equal(4.5, item.AverageRating);
        Assert.Equal(2, item.TotalReviews);
        Assert.Equal(2, result.TotalCount);
    }

    private static Task<PagedResponse<TherapistResponseDto>> ReadPageAsync(
        TherapistService service, bool filter, int page, int size) => filter
        ? service.FilterAsync(new TherapistFilterDto(), page, size)
        : service.GetAllAsync(page, size);

    private static async Task<List<Therapist>> SeedManyAsync(ApplicationDbContext context, int count)
    {
        var therapists = Enumerable.Range(1, count).Select(index => new Therapist
        {
            User = new ApplicationUser { FirstName = "Therapist", LastName = index.ToString(), IsActive = true },
            VerificationStatus = TherapistVerificationStatus.Approved, Biography = "Pagination test",
            Specialization = "Psychotherapy", HourlyRate = index, PricePerSession = index
        }).ToList();
        context.Therapists.AddRange(therapists);
        await context.SaveChangesAsync();
        return therapists;
    }
}
