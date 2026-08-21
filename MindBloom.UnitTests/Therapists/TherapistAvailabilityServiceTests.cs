using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Security.Interfaces;
using MindBloom.Application.Features.Therapists.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Therapists;

public sealed class TherapistAvailabilityServiceTests
{
    [Fact]
    public async Task
        AddAvailabilityAsync_WhenTherapistDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.AddAvailabilityAsync(
                    999,
                    CreateRequest()));
    }

    [Fact]
    public async Task
        AddAvailabilityAsync_WhenStartTimeEqualsEndTime_ThrowsBadRequestException()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        var request =
            new CreateAvailabilityDto
            {
                DayOfWeek =
                    DayOfWeek.Monday,

                StartTime =
                    new TimeSpan(
                        10,
                        0,
                        0),

                EndTime =
                    new TimeSpan(
                        10,
                        0,
                        0)
            };

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BadRequestException>(
                () =>
                    service.AddAvailabilityAsync(
                        therapist.UserId,
                        request));

        Assert.Equal(
            "Start time must be earlier than end time.",
            exception.Message);
    }

    [Fact]
    public async Task
        AddAvailabilityAsync_WhenIntervalOverlapsExistingAvailability_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        context.TherapistAvailabilities.Add(
            new TherapistAvailability
            {
                TherapistId =
                    therapist.Id,

                DayOfWeek =
                    DayOfWeek.Monday,

                StartTime =
                    new TimeSpan(
                        9,
                        0,
                        0),

                EndTime =
                    new TimeSpan(
                        12,
                        0,
                        0)
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var request =
            new CreateAvailabilityDto
            {
                DayOfWeek =
                    DayOfWeek.Monday,

                StartTime =
                    new TimeSpan(
                        11,
                        0,
                        0),

                EndTime =
                    new TimeSpan(
                        13,
                        0,
                        0)
            };

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.AddAvailabilityAsync(
                        therapist.UserId,
                        request));

        Assert.Equal(
            "Working hours overlap an existing interval.",
            exception.Message);
    }

    [Fact]
    public async Task
        AddAvailabilityAsync_WhenIntervalTouchesExistingEnd_DoesNotTreatItAsOverlap()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        context.TherapistAvailabilities.Add(
            new TherapistAvailability
            {
                TherapistId =
                    therapist.Id,

                DayOfWeek =
                    DayOfWeek.Monday,

                StartTime =
                    new TimeSpan(
                        9,
                        0,
                        0),

                EndTime =
                    new TimeSpan(
                        12,
                        0,
                        0)
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service.AddAvailabilityAsync(
            therapist.UserId,
            new CreateAvailabilityDto
            {
                DayOfWeek =
                    DayOfWeek.Monday,

                StartTime =
                    new TimeSpan(
                        12,
                        0,
                        0),

                EndTime =
                    new TimeSpan(
                        14,
                        0,
                        0)
            });

        Assert.Equal(
            2,
            await context
                .TherapistAvailabilities
                .CountAsync());
    }

    [Fact]
    public async Task
        AddAvailabilityAsync_WithValidInterval_CreatesAvailability()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        var service =
            CreateService(
                context);

        await service.AddAvailabilityAsync(
            therapist.UserId,
            CreateRequest());

        var stored =
            await context
                .TherapistAvailabilities
                .SingleAsync();

        Assert.Equal(
            DayOfWeek.Monday,
            stored.DayOfWeek);

        Assert.Equal(
            new TimeSpan(
                9,
                0,
                0),
            stored.StartTime);

        Assert.Equal(
            new TimeSpan(
                11,
                0,
                0),
            stored.EndTime);
    }

    private static CreateAvailabilityDto
        CreateRequest()
    {
        return new CreateAvailabilityDto
        {
            DayOfWeek =
                DayOfWeek.Monday,

            StartTime =
                new TimeSpan(
                    9,
                    0,
                    0),

            EndTime =
                new TimeSpan(
                    11,
                    0,
                    0)
        };
    }

    private static async Task<Therapist>
        SeedTherapistAsync(
            ApplicationDbContext context)
    {
        var user =
            new ApplicationUser
            {
                UserName =
                    "therapist@test.local",

                Email =
                    "therapist@test.local",

                FirstName =
                    "Test",

                LastName =
                    "Therapist",

                IsActive =
                    true,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.Users.Add(
            user);

        await context.SaveChangesAsync();

        var therapist =
            new Therapist
            {
                UserId =
                    user.Id,

                Biography =
                    "Unit test",

                Specialization =
                    "Psychotherapy",

                HourlyRate =
                    50m,

                PricePerSession =
                    50m,

                ExperienceYears =
                    5,

                Country =
                    "Bosnia and Herzegovina",

                City =
                    "Mostar",

                Address =
                    "Test address",

                Education =
                    "Test education"
            };

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        return therapist;
    }

    private static TherapistService
        CreateService(
            ApplicationDbContext context)
    {
        var environment =
            new Mock<
                IWebHostEnvironment>();

        var geocodingService =
            new Mock<
                IGeocodingService>();

        var securityAuditService =
            new Mock<
                ISecurityAuditService>();

        var therapistClientAccessService =
            new Mock<
                ITherapistClientAccessService>();

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

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"availability-unit-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }
}