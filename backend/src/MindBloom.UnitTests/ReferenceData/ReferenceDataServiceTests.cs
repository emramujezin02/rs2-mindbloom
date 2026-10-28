using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.ReferenceData.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.Application.Common.Exceptions;

namespace MindBloom.UnitTests.ReferenceData;

public sealed class ReferenceDataServiceTests
{
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task DeleteUsedSpecialization_RemainsExplicitBusinessConflict(bool usesForeignKey)
    {
        await using var context = CreateContext();
        var specialization = new TherapistSpecialization { Name = "Used specialization" };
        context.TherapistSpecializations.Add(specialization);
        await context.SaveChangesAsync();
        context.Therapists.Add(new Therapist
        {
            UserId = 1, Biography = "Biography", Specialization = specialization.Name,
            SpecializationId = usesForeignKey ? specialization.Id : null
        });
        await context.SaveChangesAsync();

        var error = await Assert.ThrowsAsync<BusinessException>(() => new ReferenceDataService(context)
            .DeleteTherapistSpecializationAsync(specialization.Id));

        Assert.Contains("Deactivate it instead", error.Message);
        Assert.False(specialization.IsDeleted);
        Assert.True(specialization.IsActive);
    }

    [Theory]
    [InlineData("")]
    [InlineData("A")]
    [InlineData(null)]
    public async Task InvalidSpecializationName_RemainsExplicitBusinessError(string? name)
    {
        await using var context = CreateContext();
        await Assert.ThrowsAsync<BusinessException>(() => new ReferenceDataService(context)
            .CreateTherapistSpecializationAsync(new CreateTherapistSpecializationDto { Name = name! }));
        Assert.Empty(context.TherapistSpecializations);
    }

    [Fact]
    public async Task TooLongSpecializationName_RemainsExplicitBusinessError()
    {
        await using var context = CreateContext();
        await Assert.ThrowsAsync<BusinessException>(() => new ReferenceDataService(context)
            .CreateTherapistSpecializationAsync(new CreateTherapistSpecializationDto { Name = new string('A', 151) }));
        Assert.Empty(context.TherapistSpecializations);
    }

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
