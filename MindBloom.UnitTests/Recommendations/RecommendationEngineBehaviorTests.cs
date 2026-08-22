using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Recommendations.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Recommendations;

namespace MindBloom.UnitTests.Recommendations;

public sealed class RecommendationEngineBehaviorTests
{
    [Fact]
    public async Task
        SameInput_ReturnsSameRecommendationResult()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "deterministic-client@test.local",
                "Deterministic",
                "Client");

        var firstTherapistUser =
            CreateUser(
                "deterministic-first@test.local",
                "First",
                "Therapist");

        var secondTherapistUser =
            CreateUser(
                "deterministic-second@test.local",
                "Second",
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
                60m,
                8),

            CreateTherapist(
                secondTherapistUser.Id,
                45m,
                4));

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        var request =
            new TherapistRecommendationRequestDto
            {
                Take =
                    10,

                MinimumExperienceYears =
                    5,

                MaximumPricePerSession =
                    100m
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

        Assert.NotEmpty(
            firstResult);

        for (var index = 0;
             index < firstResult.Count;
             index++)
        {
            var first =
                firstResult[index];

            var second =
                secondResult[index];

            Assert.Equal(
                first.TherapistId,
                second.TherapistId);

            Assert.Equal(
                first.Score,
                second.Score);

            Assert.Equal(
                first.MatchPercentage,
                second.MatchPercentage);

            Assert.Equal(
                first.Reasons.Count,
                second.Reasons.Count);

            for (var reasonIndex = 0;
                 reasonIndex <
                 first.Reasons.Count;
                 reasonIndex++)
            {
                Assert.Equal(
                    first.Reasons[
                            reasonIndex]
                        .Criterion,
                    second.Reasons[
                            reasonIndex]
                        .Criterion);

                Assert.Equal(
                    first.Reasons[
                            reasonIndex]
                        .AwardedPoints,
                    second.Reasons[
                            reasonIndex]
                        .AwardedPoints);

                Assert.Equal(
                    first.Reasons[
                            reasonIndex]
                        .MaximumPoints,
                    second.Reasons[
                            reasonIndex]
                        .MaximumPoints);

                Assert.Equal(
                    first.Reasons[
                            reasonIndex]
                        .Explanation,
                    second.Reasons[
                            reasonIndex]
                        .Explanation);
            }
        }
    }

    [Fact]
    public async Task
        Recommendation_ContainsExplanationForScoringCriteria()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "explanation-client@test.local",
                "Explanation",
                "Client");

        var therapistUser =
            CreateUser(
                "explanation-therapist@test.local",
                "Explanation",
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

        context.Therapists.Add(
            CreateTherapist(
                therapistUser.Id,
                50m,
                7));

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
                            80m,

                        MinimumExperienceYears =
                            5,

                        Take =
                            10
                    });

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
                    reason.AwardedPoints >=
                    0m);

                Assert.True(
                    reason.MaximumPoints >
                    0m);

                Assert.True(
                    reason.AwardedPoints <=
                    reason.MaximumPoints);
            });

        Assert.Contains(
            recommendation.Reasons,
            reason =>
                reason.Criterion ==
                "Price");

        Assert.Contains(
            recommendation.Reasons,
            reason =>
                reason.Criterion ==
                "Experience");

        Assert.Contains(
            recommendation.Reasons,
            reason =>
                reason.Criterion ==
                "Specialization");

        Assert.Contains(
            recommendation.Reasons,
            reason =>
                reason.Criterion ==
                "Initial assessment");
    }

    [Fact]
    public async Task
        Recommendation_ScoreIsValidAndMatchesPercentage()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "score-client@test.local",
                "Score",
                "Client");

        var therapistUser =
            CreateUser(
                "score-therapist@test.local",
                "Score",
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

        context.Therapists.Add(
            CreateTherapist(
                therapistUser.Id,
                50m,
                10));

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
                            100m,

                        MinimumExperienceYears =
                            5
                    });

        var recommendation =
            Assert.Single(
                result);

        Assert.InRange(
            recommendation.Score,
            0m,
            100m);

        var expectedPercentage =
            (int)Math.Round(
                recommendation.Score,
                MidpointRounding
                    .AwayFromZero);

        Assert.Equal(
            expectedPercentage,
            recommendation
                .MatchPercentage);

        /*
         * Za ovaj setup bodovi su čiste vrijednosti
         * bez problematičnih decimalnih razlomaka,
         * pa suma explanation stavki treba dati
         * ukupan score.
         */
        var scoreFromReasons =
            recommendation.Reasons
                .Sum(
                    reason =>
                        reason.AwardedPoints);

        Assert.Equal(
            recommendation.Score,
            scoreFromReasons);
    }

    [Fact]
    public async Task
        Recommendations_AreSortedByScoreDescending()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "sorting-client@test.local",
                "Sorting",
                "Client");

        var strongUser =
            CreateUser(
                "sorting-strong@test.local",
                "Strong",
                "Therapist");

        var mediumUser =
            CreateUser(
                "sorting-medium@test.local",
                "Medium",
                "Therapist");

        var weakUser =
            CreateUser(
                "sorting-weak@test.local",
                "Weak",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            strongUser,
            mediumUser,
            weakUser);

        await context.SaveChangesAsync();

        context.Clients.Add(
            new Client
            {
                UserId =
                    clientUser.Id
            });

        var strongTherapist =
            CreateTherapist(
                strongUser.Id,
                50m,
                10);

        var mediumTherapist =
            CreateTherapist(
                mediumUser.Id,
                50m,
                5);

        var weakTherapist =
            CreateTherapist(
                weakUser.Id,
                50m,
                1);

        context.Therapists.AddRange(
            weakTherapist,
            strongTherapist,
            mediumTherapist);

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
                        MinimumExperienceYears =
                            10,

                        MaximumPricePerSession =
                            100m,

                        Take =
                            10
                    });

        Assert.Equal(
            3,
            result.Count);

        Assert.Equal(
            strongTherapist.Id,
            result[0]
                .TherapistId);

        Assert.Equal(
            mediumTherapist.Id,
            result[1]
                .TherapistId);

        Assert.Equal(
            weakTherapist.Id,
            result[2]
                .TherapistId);

        Assert.True(
            result[0].Score >
            result[1].Score);

        Assert.True(
            result[1].Score >
            result[2].Score);

        for (var index = 1;
             index < result.Count;
             index++)
        {
            Assert.True(
                result[index - 1]
                    .Score >=
                result[index]
                    .Score);
        }
    }

    [Fact]
    public async Task
        ChangingClientPreference_ChangesRecommendationResult()
    {
        await using var context =
            CreateContext();

        var clientUser =
            CreateUser(
                "preference-client@test.local",
                "Preference",
                "Client");

        var affordableUser =
            CreateUser(
                "preference-affordable@test.local",
                "Affordable",
                "Therapist");

        var premiumUser =
            CreateUser(
                "preference-premium@test.local",
                "Premium",
                "Therapist");

        context.Users.AddRange(
            clientUser,
            affordableUser,
            premiumUser);

        await context.SaveChangesAsync();

        var client =
            new Client
            {
                UserId =
                    clientUser.Id,

                MaximumPricePerSession =
                    150m
            };

        context.Clients.Add(
            client);

        var affordableTherapist =
            CreateTherapist(
                affordableUser.Id,
                50m,
                5);

        var premiumTherapist =
            CreateTherapist(
                premiumUser.Id,
                120m,
                10);

        context.Therapists.AddRange(
            affordableTherapist,
            premiumTherapist);

        await context.SaveChangesAsync();

        var service =
            new RecommendationService(
                context);

        /*
         * Request nema svoj MaximumPricePerSession.
         * Zato recommendation engine koristi
         * sačuvanu client preference vrijednost.
         */
        var request =
            new TherapistRecommendationRequestDto
            {
                Take =
                    10
            };

        var beforePreferenceChange =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    request);

        Assert.Equal(
            2,
            beforePreferenceChange.Count);

        Assert.Contains(
            beforePreferenceChange,
            item =>
                item.TherapistId ==
                premiumTherapist.Id);

        /*
         * Klijent mijenja svoju sačuvanu
         * preference maksimalne cijene.
         */
        var storedClient =
            await context.Clients
                .SingleAsync(
                    item =>
                        item.Id ==
                        client.Id);

        storedClient.MaximumPricePerSession =
            70m;

        await context
            .SaveChangesAsync();

        context.ChangeTracker
            .Clear();

        var afterPreferenceChange =
            await service
                .GetRecommendationsAsync(
                    clientUser.Id,
                    request);

        var remaining =
            Assert.Single(
                afterPreferenceChange);

        Assert.Equal(
            affordableTherapist.Id,
            remaining.TherapistId);

        Assert.DoesNotContain(
            afterPreferenceChange,
            item =>
                item.TherapistId ==
                premiumTherapist.Id);

        Assert.NotEqual(
            beforePreferenceChange
                .Select(
                    item =>
                        item.TherapistId)
                .ToArray(),

            afterPreferenceChange
                .Select(
                    item =>
                        item.TherapistId)
                .ToArray());
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"recommendation-engine-"
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

            NormalizedUserName =
                email.ToUpperInvariant(),

            Email =
                email,

            NormalizedEmail =
                email.ToUpperInvariant(),

            FirstName =
                firstName,

            LastName =
                lastName,

            IsActive =
                true,

            IsBlocked =
                false,

            EmailConfirmed =
                true,

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }

    private static Therapist
        CreateTherapist(
            int userId,
            decimal price,
            int experienceYears)
    {
        return new Therapist
        {
            UserId =
                userId,

            Biography =
                "Recommendation engine test therapist.",

            Specialization =
                "General psychotherapy",

            PricePerSession =
                price,

            HourlyRate =
                price,

            ExperienceYears =
                experienceYears,

            VerificationStatus =
                TherapistVerificationStatus
                    .Approved,

            Country =
                "Bosnia and Herzegovina",

            City =
                "Mostar",

            Address =
                "Test address",

            Education =
                "Test education",

            OffersOnline =
                true,

            OffersInPerson =
                true
        };
    }
}