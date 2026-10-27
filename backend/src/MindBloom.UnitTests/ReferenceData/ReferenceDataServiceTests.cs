using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.ReferenceData;

public sealed class ReferenceDataServiceTests
{
    [Fact]
    public async Task GetActiveTherapyApproachesAsync_ReturnsActiveNotDeletedDtosSortedByName()
    {
        await using var context = CreateContext();
        var alpha = new TherapyApproach { Name = "Alpha", Description = null };
        context.TherapyApproaches.AddRange(
            new TherapyApproach { Name = "Zulu", Description = "Zulu description" },
            alpha,
            new TherapyApproach { Name = "Inactive", IsActive = false },
            new TherapyApproach { Name = "Deleted", IsActive = true, IsDeleted = true });
        await context.SaveChangesAsync();

        var result = await new ReferenceDataService(context).GetActiveTherapyApproachesAsync();

        Assert.Collection(result,
            first =>
            {
                Assert.IsType<TherapyApproachResponseDto>(first);
                Assert.Equal("Alpha", first.Name);
                Assert.Null(first.Description);
                Assert.True(first.IsActive);
                Assert.Equal(alpha.CreatedAtUtc, first.CreatedAtUtc);
            },
            second =>
            {
                Assert.Equal("Zulu", second.Name);
                Assert.Equal("Zulu description", second.Description);
                Assert.True(second.IsActive);
            });
    }

    [Fact]
    public async Task GetActiveTherapyApproachesAsync_WhenNoApproachesMatch_ReturnsEmptyList()
    {
        await using var context = CreateContext();
        context.TherapyApproaches.Add(new TherapyApproach { Name = "Inactive", IsActive = false });
        await context.SaveChangesAsync();

        var result = await new ReferenceDataService(context).GetActiveTherapyApproachesAsync();

        Assert.Empty(result);
    }

    private static ApplicationDbContext CreateContext() => new(
        new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase($"reference-data-unit-{Guid.NewGuid():N}").Options);
}
