using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Recommendations;

namespace MindBloom.UnitTests.Recommendations;

public sealed class RecommendationServiceTests
{
    [Fact]
    public async Task
        GetRecommendationsAsync_WhenRequestIsNull_ThrowsArgumentNullException()
    {
        await using var context =
            CreateContext();

        var service =
            new RecommendationService(
                context);

        await Assert.ThrowsAsync<
            ArgumentNullException>(
            () =>
                service.GetRecommendationsAsync(
                    1,
                    null!));
    }

    [Fact]
    public async Task
        GetRecommendationsAsync_WhenClientDoesNotExist_ThrowsKeyNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            new RecommendationService(
                context);

        var request =
            new TherapistRecommendationRequestDto();

        var exception =
            await Assert.ThrowsAsync<
                KeyNotFoundException>(
                () =>
                    service
                        .GetRecommendationsAsync(
                            999,
                            request));

        Assert.Equal(
            "Client profile was not found for the authenticated user.",
            exception.Message);
    }

    [Fact]
    public async Task
        GetRecommendationsAsync_ReturnsOnlyApprovedActiveTherapists()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client@test.local",
                "Client",
                "User");

        var approvedUser =
            CreateUser(
                "approved@test.local",
                "Approved",
                "Therapist");

        var pendingUser =
            CreateUser(
                "pending@test.local",
                "Pending",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            approvedUser,
            pendingUser);

        await context.SaveChangesAsync();

        var client =
            new Client
            {
                UserId =
                    clientUser.Id
            };

        context.Clients.Add(
            client);

        var approvedTherapist =
            CreateTherapist(
                approvedUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        var pendingTherapist =
            CreateTherapist(
                pendingUser.Id,
                TherapistVerificationStatus.Pending,
                40m,
                10);

        context.Therapists.AddRange(
            approvedTherapist,
            pendingTherapist);

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var result =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto
                    {
                        Take =
                            10
                    });

        var recommendation =
            Assert.Single(
                result);

        Assert.Equal(
            approvedTherapist.Id,
            recommendation.TherapistId);

        Assert.Equal(
            "Approved Therapist",
            recommendation.FullName);

        Assert.InRange(
            recommendation.Score,
            0m,
            100m);
    }

    [Fact]
    public async Task
        GetRecommendationsAsync_WhenTakeExceedsMaximum_ReturnsAtMostFifty()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client@test.local",
                "Client",
                "User");

        context.Users.Add(
            clientUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        for (var index = 0;
             index < 55;
             index++)
        {
            var therapistUser =
                CreateUser(
                    $"therapist{index}@test.local",
                    "Therapist",
                    index.ToString());

            context.Users.Add(
                therapistUser);

            await context
                .SaveChangesAsync();

            context.Therapists.Add(
                CreateTherapist(
                    therapistUser.Id,
                    TherapistVerificationStatus.Approved,
                    50m,
                    5));
        }

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var result =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto
                    {
                        Take =
                            500
                    });

        Assert.Equal(
            50,
            result.Count);
    }

    [Fact]
    public async Task
      GetRecommendationsAsync_ExcludesTherapistAboveRequestedBudget()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client@test.local",
                "Client",
                "User");

        var affordableUser =
            CreateUser(
                "affordable@test.local",
                "Affordable",
                "Therapist");

        var expensiveUser =
            CreateUser(
                "expensive@test.local",
                "Expensive",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            affordableUser,
            expensiveUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        var affordable =
            CreateTherapist(
                affordableUser.Id,
                TherapistVerificationStatus.Approved,
                40m,
                5);

        var expensive =
            CreateTherapist(
                expensiveUser.Id,
                TherapistVerificationStatus.Approved,
                120m,
                5);

        context.Therapists.AddRange(
            affordable,
            expensive);

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var result =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto
                    {
                        MaximumPricePerSession =
                            50m
                    });

        var recommendation =
            Assert.Single(
                result);

        Assert.Equal(
            affordable.Id,
            recommendation.TherapistId);

        Assert.DoesNotContain(
            result,
            item =>
                item.TherapistId ==
                expensive.Id);
    }

    [Fact]
    public async Task
    GetRecommendationsAsync_SameInput_ReturnsSameResultAndOrder()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client-deterministic@test.local",
                "Client",
                "User");

        var firstTherapistUser =
            CreateUser(
                "therapist-a@test.local",
                "Anna",
                "Therapist");

        var secondTherapistUser =
            CreateUser(
                "therapist-b@test.local",
                "Bella",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            firstTherapistUser,
            secondTherapistUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        context.Therapists.AddRange(
            CreateTherapist(
                firstTherapistUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5),

            CreateTherapist(
                secondTherapistUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5));

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var request =
            new TherapistRecommendationRequestDto
            {
                Take = 10
            };

        var firstResult =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    request);

        var secondResult =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    request);

        Assert.Equal(
            firstResult.Count,
            secondResult.Count);

        Assert.Equal(
            firstResult
                .Select(x => x.TherapistId),
            secondResult
                .Select(x => x.TherapistId));

        Assert.Equal(
            firstResult
                .Select(x => x.Score),
            secondResult
                .Select(x => x.Score));
    }

    [Fact]
    public async Task
    GetRecommendationsAsync_ReturnsTransparentExplanationForEveryScoringCriterion()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client-explanation@test.local",
                "Client",
                "User");

        var therapistUser =
            CreateUser(
                "therapist-explanation@test.local",
                "Explain",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            therapistUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        var therapist =
            CreateTherapist(
                therapistUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var result =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto());

        var recommendation =
            Assert.Single(
                result);

        Assert.NotEmpty(
            recommendation.Reasons);

        Assert.All(
            recommendation.Reasons,
            reason =>
            {
                Assert.False(
                    string.IsNullOrWhiteSpace(
                        reason.Criterion));

                Assert.False(
                    string.IsNullOrWhiteSpace(
                        reason.Explanation));

                Assert.True(
                    reason.MaximumPoints > 0);

                Assert.InRange(
                    reason.AwardedPoints,
                    0m,
                    reason.MaximumPoints);
            });

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Specialization");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Therapy approach");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Initial assessment");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Preferred schedule");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Price");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Experience");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Rating");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Availability");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Previous appointments");

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                "Favorite therapist");
    }

    [Fact]
    public async Task
    GetRecommendationsAsync_PreferredTherapyApproach_IncreasesMatchingTherapistScore()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client-approach@test.local",
                "Client",
                "User");

        var matchingUser =
            CreateUser(
                "matching-approach@test.local",
                "Matching",
                "Therapist");

        var nonMatchingUser =
            CreateUser(
                "nonmatching-approach@test.local",
                "NonMatching",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            matchingUser,
            nonMatchingUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        var matchingTherapist =
            CreateTherapist(
                matchingUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        var nonMatchingTherapist =
            CreateTherapist(
                nonMatchingUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        context.Therapists.AddRange(
            matchingTherapist,
            nonMatchingTherapist);

        await context.SaveChangesAsync();

        matchingTherapist
            .TherapyApproaches
            .Add(
                new TherapistTherapyApproach
                {
                    TherapistId =
                        matchingTherapist.Id,

                    TherapyApproachId =
                        1001
                });

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var result =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto
                    {
                        PreferredTherapyApproachIds =
                            [1001]
                    });

        Assert.Equal(
            matchingTherapist.Id,
            result.First()
                .TherapistId);

        var matching =
            result.Single(
                x =>
                    x.TherapistId ==
                    matchingTherapist.Id);

        var nonMatching =
            result.Single(
                x =>
                    x.TherapistId ==
                    nonMatchingTherapist.Id);

        Assert.True(
            matching.Score >
            nonMatching.Score);

        Assert.Contains(
            matching.Reasons,
            x =>
                x.Criterion ==
                    "Therapy approach" &&
                x.AwardedPoints > 0);
    }

    [Fact]
    public async Task
    GetRecommendationsAsync_ChangingPreference_ChangesRanking()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client-preference-change@test.local",
                "Client",
                "User");

        var firstUser =
            CreateUser(
                "first-preference@test.local",
                "First",
                "Therapist");

        var secondUser =
            CreateUser(
                "second-preference@test.local",
                "Second",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            firstUser,
            secondUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        var firstTherapist =
            CreateTherapist(
                firstUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        firstTherapist.SpecializationId =
            2001;

        var secondTherapist =
            CreateTherapist(
                secondUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        secondTherapist.SpecializationId =
            2002;

        context.Therapists.AddRange(
            firstTherapist,
            secondTherapist);

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var firstResult =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto
                    {
                        PreferredSpecializationIds =
                            [2001]
                    });

        var secondResult =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto
                    {
                        PreferredSpecializationIds =
                            [2002]
                    });

        Assert.Equal(
            firstTherapist.Id,
            firstResult.First()
                .TherapistId);

        Assert.Equal(
            secondTherapist.Id,
            secondResult.First()
                .TherapistId);
    }

    [Fact]
    public async Task
    GetRecommendationsAsync_WithoutExplicitPreferences_ReturnsStableColdStartFallback()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client-cold-start@test.local",
                "Client",
                "User");

        var therapistUser =
            CreateUser(
                "therapist-cold-start@test.local",
                "Cold",
                "Start");

        context.Users.AddRange(
            clientUser,
            therapistUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        var therapist =
            CreateTherapist(
                therapistUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var result =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto());

        var recommendation =
            Assert.Single(
                result);

        Assert.InRange(
            recommendation.Score,
            0m,
            100m);

        Assert.NotEmpty(
            recommendation.Reasons);

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                    "Specialization" &&
                x.AwardedPoints > 0);

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                    "Therapy approach" &&
                x.AwardedPoints > 0);

        Assert.Contains(
            recommendation.Reasons,
            x =>
                x.Criterion ==
                    "Initial assessment" &&
                x.AwardedPoints > 0);
    }

    [Fact]
    public async Task
    GetRecommendationsAsync_WhenScoresAreEqual_SortsByTherapistIdAsFinalTieBreaker()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "client-tie@test.local",
                "Client",
                "User");

        var firstUser =
            CreateUser(
                "tie-a@test.local",
                "Tie",
                "A");

        var secondUser =
            CreateUser(
                "tie-b@test.local",
                "Tie",
                "B");

        context.Users.AddRange(
            clientUser,
            firstUser,
            secondUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        var firstTherapist =
            CreateTherapist(
                firstUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        var secondTherapist =
            CreateTherapist(
                secondUser.Id,
                TherapistVerificationStatus.Approved,
                50m,
                5);

        context.Therapists.AddRange(
            firstTherapist,
            secondTherapist);

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var result =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    new TherapistRecommendationRequestDto());

        Assert.Equal(
            2,
            result.Count);

        Assert.Equal(
            result
                .OrderBy(x => x.TherapistId)
                .Select(x => x.TherapistId),
            result
                .Select(x => x.TherapistId));
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"recommendation-unit-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static ApplicationUser
        CreateUser(
            string email,
            string firstName,
            string lastName)
    {
        return new ApplicationUser
        {
            UserName =
                email,

            Email =
                email,

            FirstName =
                firstName,

            LastName =
                lastName,

            IsActive =
                true,

            IsBlocked =
                false,

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }

    private static Therapist
        CreateTherapist(
            int userId,
            TherapistVerificationStatus status,
            decimal price,
            int experienceYears)
    {
        return new Therapist
        {
            UserId =
                userId,

            Biography =
                "Unit test therapist.",

            Specialization =
                "General psychotherapy",

            PricePerSession =
                price,

            HourlyRate =
                price,

            ExperienceYears =
                experienceYears,

            VerificationStatus =
                status,

            Country =
                "Bosnia and Herzegovina",

            City =
                "Mostar",

            Address =
                "Test address",

            Education =
                "Test education",

            OffersOnline =
                true
        };
    }
}