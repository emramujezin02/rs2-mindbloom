using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Journal;

public sealed class MoodAnalyticsTests
{
    [Fact]
    public async Task
        GetMyAnalyticsAsync_WhenThereAreNoEntries_ReturnsEmptyAnalytics()
    {
        await using var context =
            CreateContext();

        var user =
            CreateUser();

        context.Users.Add(
            user);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    user.Id
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var fromUtc =
            new DateTime(
                2026,
                8,
                1,
                0,
                0,
                0,
                DateTimeKind.Utc);

        var toUtc =
            new DateTime(
                2026,
                8,
                7,
                23,
                59,
                59,
                DateTimeKind.Utc);

        var result =
            await service
                .GetMyAnalyticsAsync(
                    user.Id,
                    fromUtc,
                    toUtc);

        Assert.Equal(
            0,
            result.TotalEntries);

        Assert.Null(
            result.AverageMood);

        Assert.Null(
            result.MostFrequentEmotion);

        Assert.Equal(
            "InsufficientData",
            result.Trend);

        Assert.Empty(
            result.Points);

        Assert.Empty(
            result.Emotions);
    }

    [Fact]
    public async Task
     GetMyAnalyticsAsync_WithImprovingMood_ReturnsImprovingTrend()
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

        var firstEntry =
            CreateMoodEntry(
                client.Id,
                2,
                "Sad");

        var secondEntry =
            CreateMoodEntry(
                client.Id,
                2,
                "Tired");

        var thirdEntry =
            CreateMoodEntry(
                client.Id,
                4,
                "Happy");

        var fourthEntry =
            CreateMoodEntry(
                client.Id,
                5,
                "Happy");

        context.MoodEntries.AddRange(
            firstEntry,
            secondEntry,
            thirdEntry,
            fourthEntry);

        await context.SaveChangesAsync();

        /*
         * ApplicationDbContext pri insertu
         * postavlja CreatedAtUtc na UtcNow.
         * Zato nakon SaveChanges eksplicitno
         * postavljamo determinističke datume.
         */
        firstEntry.CreatedAtUtc =
            new DateTime(
                2026,
                8,
                1,
                10,
                0,
                0,
                DateTimeKind.Utc);

        secondEntry.CreatedAtUtc =
            new DateTime(
                2026,
                8,
                2,
                10,
                0,
                0,
                DateTimeKind.Utc);

        thirdEntry.CreatedAtUtc =
            new DateTime(
                2026,
                8,
                3,
                10,
                0,
                0,
                DateTimeKind.Utc);

        fourthEntry.CreatedAtUtc =
            new DateTime(
                2026,
                8,
                4,
                10,
                0,
                0,
                DateTimeKind.Utc);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var result =
            await service
                .GetMyAnalyticsAsync(
                    user.Id,
                    new DateTime(
                        2026,
                        8,
                        1,
                        0,
                        0,
                        0,
                        DateTimeKind.Utc),
                    new DateTime(
                        2026,
                        8,
                        4,
                        23,
                        59,
                        59,
                        DateTimeKind.Utc));

        Assert.Equal(
            4,
            result.TotalEntries);

        Assert.Equal(
            "Improving",
            result.Trend);

        Assert.Equal(
            "Happy",
            result.MostFrequentEmotion);

        Assert.NotNull(
            result.PreviousAverageMood);

        Assert.NotNull(
            result.RecentAverageMood);

        Assert.True(
            result.RecentAverageMood >
            result.PreviousAverageMood);
    }

    [Fact]
    public async Task
     GetMyAnalyticsAsync_WithSingleDay_ReturnsInsufficientData()
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
            CreateMoodEntry(
                client.Id,
                4,
                "Calm");

        context.MoodEntries.Add(
            entry);

        await context.SaveChangesAsync();

        entry.CreatedAtUtc =
            new DateTime(
                2026,
                8,
                1,
                10,
                0,
                0,
                DateTimeKind.Utc);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var result =
            await service
                .GetMyAnalyticsAsync(
                    user.Id,
                    new DateTime(
                        2026,
                        8,
                        1,
                        0,
                        0,
                        0,
                        DateTimeKind.Utc),
                    new DateTime(
                        2026,
                        8,
                        1,
                        23,
                        59,
                        59,
                        DateTimeKind.Utc));

        Assert.Equal(
            1,
            result.TotalEntries);

        Assert.Equal(
            "InsufficientData",
            result.Trend);

        Assert.Single(
            result.Points);
    }

    private static MoodEntry
        CreateMoodEntry(
            int clientId,
            int mood,
            string emotion)
    {
        return new MoodEntry
        {
            ClientId =
                clientId,

            MoodScore =
                mood,

            Emotion =
                emotion,

            Notes =
                string.Empty
        };
    }

    private static JournalEntryService
        CreateService(
            ApplicationDbContext context)
    {
        var access =
            new Mock<
                ITherapistClientAccessService>();

        return new JournalEntryService(
            context,
            access.Object);
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"mood-analytics-unit-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static ApplicationUser
        CreateUser()
    {
        return new ApplicationUser
        {
            UserName =
                "analytics@test.local",

            Email =
                "analytics@test.local",

            FirstName =
                "Analytics",

            LastName =
                "Client",

            IsActive =
                true,

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }
}