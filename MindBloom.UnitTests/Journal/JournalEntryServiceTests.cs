using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.JournalEntries.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Journal;

public sealed class JournalEntryServiceTests
{
    [Fact]
    public async Task
        CreateAsync_WhenMoodIsBelowAllowedRange_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var accessService =
            new Mock<
                ITherapistClientAccessService>();

        var service =
            new JournalEntryService(
                context,
                accessService.Object);

        var request =
            new CreateJournalEntryDto
            {
                Mood =
                    0,

                Emotions =
                    ["Happy"],

                Note =
                    "Test."
            };

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.CreateAsync(
                        1,
                        request));

        Assert.Equal(
            "Mood must be between 1 and 5.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreateAsync_WhenMoodIsAboveAllowedRange_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        var request =
            new CreateJournalEntryDto
            {
                Mood =
                    6,

                Emotions =
                    ["Happy"]
            };

        await Assert.ThrowsAsync<
            BusinessException>(
            () =>
                service.CreateAsync(
                    1,
                    request));
    }

    [Fact]
    public async Task
        CreateAsync_WhenClientDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        var request =
            new CreateJournalEntryDto
            {
                Mood =
                    4,

                Emotions =
                    ["Happy"],

                Note =
                    "Good day."
            };

        var exception =
            await Assert.ThrowsAsync<
                NotFoundException>(
                () =>
                    service.CreateAsync(
                        999,
                        request));

        Assert.Equal(
            "Client not found.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreateAsync_WithValidRequest_CreatesMoodEntry()
    {
        await using var context =
            CreateContext();

        var user =
            CreateUser();

        context.Users.Add(
            user);

        await context.SaveChangesAsync();

        var client =
            new Client
            {
                UserId =
                    user.Id
            };

        context.Clients.Add(
            client);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var result =
            await service.CreateAsync(
                user.Id,
                new CreateJournalEntryDto
                {
                    Mood =
                        5,

                    Emotions =
                        [
                            "Happy",
                            "Grateful"
                        ],

                    Note =
                        "A very good day."
                });

        Assert.Equal(
            5,
            result.Mood);

        Assert.Contains(
            "Happy",
            result.Emotions);

        Assert.Contains(
            "Grateful",
            result.Emotions);

        Assert.Equal(
            "A very good day.",
            result.Note);

        Assert.Equal(
            1,
            await context.MoodEntries
                .CountAsync());
    }

    [Fact]
    public async Task
        GetMineAsync_WhenFromDateIsAfterToDate_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        var fromUtc =
            new DateTime(
                2026,
                8,
                10,
                0,
                0,
                0,
                DateTimeKind.Utc);

        var toUtc =
            new DateTime(
                2026,
                8,
                1,
                0,
                0,
                0,
                DateTimeKind.Utc);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.GetMineAsync(
                        1,
                        1,
                        20,
                        fromUtc,
                        toUtc));

        Assert.Equal(
            "Start date cannot be later than end date.",
            exception.Message);
    }

    [Fact]
    public async Task
        GetByIdAsync_WhenEntryBelongsToAnotherClient_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var firstUser =
            CreateUser(
                "first@test.local");

        var secondUser =
            CreateUser(
                "second@test.local");

        context.Users.AddRange(
            firstUser,
            secondUser);

        await context.SaveChangesAsync();

        var firstClient =
            new Client
            {
                UserId =
                    firstUser.Id
            };

        var secondClient =
            new Client
            {
                UserId =
                    secondUser.Id
            };

        context.Clients.AddRange(
            firstClient,
            secondClient);

        await context.SaveChangesAsync();

        var entry =
            new MoodEntry
            {
                ClientId =
                    secondClient.Id,

                MoodScore =
                    3,

                Emotion =
                    "Calm",

                Notes =
                    string.Empty,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.MoodEntries.Add(
            entry);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.GetByIdAsync(
                    firstUser.Id,
                    entry.Id));
    }

    [Fact]
    public async Task
        DeleteAsync_WithExistingEntry_SoftDeletesEntry()
    {
        await using var context =
            CreateContext();

        var user =
            CreateUser();

        context.Users.Add(
            user);

        await context.SaveChangesAsync();

        var client =
            new Client
            {
                UserId =
                    user.Id
            };

        context.Clients.Add(
            client);

        await context.SaveChangesAsync();

        var entry =
            new MoodEntry
            {
                ClientId =
                    client.Id,

                MoodScore =
                    4,

                Emotion =
                    "Calm",

                Notes =
                    string.Empty,

                CreatedAtUtc =
                    DateTime.UtcNow
            };

        context.MoodEntries.Add(
            entry);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service.DeleteAsync(
            user.Id,
            entry.Id);

        var stored =
            await context.MoodEntries
                .SingleAsync();

        Assert.True(
            stored.IsDeleted);
    }

    private static JournalEntryService
        CreateService(
            ApplicationDbContext context)
    {
        var accessService =
            new Mock<
                ITherapistClientAccessService>();

        return new JournalEntryService(
            context,
            accessService.Object);
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"journal-unit-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static ApplicationUser
        CreateUser(
            string email =
                "client@test.local")
    {
        return new ApplicationUser
        {
            UserName =
                email,

            Email =
                email,

            FirstName =
                "Test",

            LastName =
                "Client",

            IsActive =
                true,

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }
}