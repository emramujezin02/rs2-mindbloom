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