using System.Runtime.CompilerServices;
using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Memberships.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.Messaging.Contracts.Notifications;

namespace MindBloom.UnitTests.Memberships;

public sealed class MembershipServiceTests
{
    [Fact]
    public async Task
        GetPlansForTherapistAsync_WhenTherapistDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service
                    .GetPlansForTherapistAsync(
                        999));
    }

    [Fact]
    public async Task
        GetPlansForTherapistAsync_WhenTherapistIsBlocked_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context,
                blocked: true);

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service
                    .GetPlansForTherapistAsync(
                        therapist.Id));
    }

    [Fact]
    public async Task
        GetPlansForTherapistAsync_ReturnsOnlyActivePlans()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        context.MembershipPlans.AddRange(
            CreatePlan(
                MembershipPlanType.TenSessions,
                "Ten sessions",
                400m,
                10,
                true),

            CreatePlan(
                MembershipPlanType.TwentySessions,
                "Twenty sessions",
                700m,
                20,
                false));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var result =
            await service
                .GetPlansForTherapistAsync(
                    therapist.Id);

        var plan =
            Assert.Single(
                result);

        Assert.Equal(
            MembershipPlanType.TenSessions,
            plan.PlanType);

        Assert.True(
            plan.IsActive);
    }

    [Fact]
    public async Task
        GetPlansForTherapistAsync_CalculatesPricePerSession()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        context.MembershipPlans.Add(
            CreatePlan(
                MembershipPlanType.TenSessions,
                "Ten sessions",
                400m,
                10,
                true));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var result =
            await service
                .GetPlansForTherapistAsync(
                    therapist.Id);

        var plan =
            Assert.Single(
                result);

        Assert.Equal(
            40m,
            plan.PricePerSession);
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenClientDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service
                    .CreatePaymentIntentAsync(
                        999,
                        new CreateMembershipPaymentIntentDto
                        {
                            TherapistId =
                                1,

                            PlanType =
                                MembershipPlanType
                                    .TenSessions
                        }));
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenTherapistDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service
                    .CreatePaymentIntentAsync(
                        client.UserId,
                        new CreateMembershipPaymentIntentDto
                        {
                            TherapistId =
                                999,

                            PlanType =
                                MembershipPlanType
                                    .TenSessions
                        }));
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenActiveMembershipAlreadyExists_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        context.ClientMemberships.Add(
            new ClientMembership
            {
                ClientId =
                    client.Id,

                TherapistId =
                    therapist.Id,

                PlanType =
                    MembershipPlanType
                        .TenSessions,

                TotalSessions =
                    10,

                RemainingSessions =
                    5,

                Price =
                    400m,

                DurationMonths =
                    6,

                IsActive =
                    true,

                PurchasedAtUtc =
                    DateTime.UtcNow
                        .AddMonths(-1),

                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddMonths(5)
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service
                        .CreatePaymentIntentAsync(
                            client.UserId,
                            new CreateMembershipPaymentIntentDto
                            {
                                TherapistId =
                                    therapist.Id,

                                PlanType =
                                    MembershipPlanType
                                        .TenSessions
                            }));

        Assert.Equal(
            "You already have an active membership for this therapist.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenPlanDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service
                    .CreatePaymentIntentAsync(
                        client.UserId,
                        new CreateMembershipPaymentIntentDto
                        {
                            TherapistId =
                                therapist.Id,

                            PlanType =
                                MembershipPlanType
                                    .ThirtySessions
                        }));
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenPlanIsInactive_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        context.MembershipPlans.Add(
            CreatePlan(
                MembershipPlanType.TenSessions,
                "Ten",
                400m,
                10,
                false));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service
                        .CreatePaymentIntentAsync(
                            client.UserId,
                            new CreateMembershipPaymentIntentDto
                            {
                                TherapistId =
                                    therapist.Id,

                                PlanType =
                                    MembershipPlanType
                                        .TenSessions
                            }));

        Assert.Equal(
            "Selected membership plan is not currently available.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenPlanPriceIsZero_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        context.MembershipPlans.Add(
            CreatePlan(
                MembershipPlanType.TenSessions,
                "Ten",
                0m,
                10,
                true));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service
                        .CreatePaymentIntentAsync(
                            client.UserId,
                            new CreateMembershipPaymentIntentDto
                            {
                                TherapistId =
                                    therapist.Id,

                                PlanType =
                                    MembershipPlanType
                                        .TenSessions
                            }));

        Assert.Equal(
            "Membership price is invalid.",
            exception.Message);
    }

    [Fact]
    public async Task
        CreatePaymentIntentAsync_WhenPlanHasNoSessions_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        context.MembershipPlans.Add(
            CreatePlan(
                MembershipPlanType.TenSessions,
                "Ten",
                400m,
                0,
                true));

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service
                        .CreatePaymentIntentAsync(
                            client.UserId,
                            new CreateMembershipPaymentIntentDto
                            {
                                TherapistId =
                                    therapist.Id,

                                PlanType =
                                    MembershipPlanType
                                        .TenSessions
                            }));

        Assert.Equal(
            "Membership plan must include at least one session.",
            exception.Message);
    }

    [Fact]
    public async Task
        GetMyMembershipsAsync_WhenMembershipExpired_DeactivatesMembership()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var membership =
            new ClientMembership
            {
                ClientId =
                    client.Id,

                TherapistId =
                    therapist.Id,

                PlanType =
                    MembershipPlanType
                        .TenSessions,

                TotalSessions =
                    10,

                RemainingSessions =
                    5,

                Price =
                    400m,

                DurationMonths =
                    6,

                IsActive =
                    true,

                PurchasedAtUtc =
                    DateTime.UtcNow
                        .AddMonths(-7),

                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddDays(-1)
            };

        context.ClientMemberships.Add(
            membership);

        await context.SaveChangesAsync();

        var publisher =
            new Mock<
                IIntegrationEventPublisher>();

        publisher
            .Setup(x =>
                x.PublishAsync(
                    It.IsAny<NotificationRequestedEvent>(),
                    It.IsAny<string>(),
                    It.IsAny<CancellationToken>()))
            .Returns(
                Task.CompletedTask);

        var service =
            CreateService(
                context,
                publisher.Object);

        await service
            .GetMyMembershipsAsync(
                client.UserId,
                pageNumber: 1,
                pageSize: 10);

        Assert.False(
            membership.IsActive);

        publisher.Verify(
            x =>
                x.PublishAsync(
                    It.IsAny<NotificationRequestedEvent>(),
                    It.IsAny<string>(),
                    It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task
        GetMyMembershipsAsync_WhenNoSessionsRemain_DeactivatesMembership()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var membership =
            new ClientMembership
            {
                ClientId =
                    client.Id,

                TherapistId =
                    therapist.Id,

                PlanType =
                    MembershipPlanType
                        .TenSessions,

                TotalSessions =
                    10,

                RemainingSessions =
                    0,

                Price =
                    400m,

                DurationMonths =
                    6,

                IsActive =
                    true,

                PurchasedAtUtc =
                    DateTime.UtcNow
                        .AddMonths(-1),

                ExpiresAtUtc =
                    DateTime.UtcNow
                        .AddMonths(5)
            };

        context.ClientMemberships.Add(
            membership);

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service
            .GetMyMembershipsAsync(
                client.UserId,
                pageNumber: 1,
                pageSize: 10);

        Assert.False(
            membership.IsActive);
    }

    [Fact]
    public async Task
        GetMyMembershipsAsync_ReturnsPagedMembershipHistory()
    {
        await using var context =
            CreateContext();

        var client =
            await SeedClientAsync(
                context);

        var therapist =
            await SeedTherapistAsync(
                context);

        var baseDate =
            DateTime.UtcNow;

        for (var i = 0; i < 55; i++)
        {
            context.ClientMemberships.Add(
                new ClientMembership
                {
                    ClientId =
                        client.Id,

                    TherapistId =
                        therapist.Id,

                    PlanType =
                        MembershipPlanType.TenSessions,

                    TotalSessions =
                        10,

                    RemainingSessions =
                        10,

                    Price =
                        400m,

                    DurationMonths =
                        6,

                    IsActive =
                        true,

                    PurchasedAtUtc =
                        baseDate
                            .AddDays(-i),

                    ExpiresAtUtc =
                        baseDate
                            .AddMonths(6)
                            .AddDays(-i)
                });
        }

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var page =
            await service
                .GetMyMembershipsAsync(
                    client.UserId,
                    pageNumber: 2,
                    pageSize: 1000);

        Assert.Equal(
            2,
            page.PageNumber);

        Assert.Equal(
            50,
            page.PageSize);

        Assert.Equal(
            55,
            page.TotalCount);

        Assert.Equal(
            2,
            page.TotalPages);

        Assert.Equal(
            5,
            page.Items.Count);

        Assert.True(
            page.HasPreviousPage);

        Assert.False(
            page.HasNextPage);
    }

    private static MembershipService
        CreateService(
            ApplicationDbContext context,
            IIntegrationEventPublisher?
                publisher = null)
    {
        var stripeVerificationService =
            (StripeVerificationService)
            RuntimeHelpers
                .GetUninitializedObject(
                    typeof(
                        StripeVerificationService));

        var eventPublisher =
            publisher ??
            new Mock<
                IIntegrationEventPublisher>()
                .Object;

        var outbox =
            new Mock<
                IOutboxWriter>();

        return new MembershipService(
            context,
            stripeVerificationService,
            eventPublisher,
            outbox.Object);
    }

    private static MembershipPlan
        CreatePlan(
            MembershipPlanType type,
            string name,
            decimal price,
            int includedSessions,
            bool isActive)
    {
        return new MembershipPlan
        {
            PlanType =
                type,

            Name =
                name,

            Description =
                "Unit test plan",

            Price =
                price,

            IncludedSessions =
                includedSessions,

            DurationMonths =
                6,

            DiscountPercentage =
                0m,

            BenefitsJson =
                "[]",

            IsActive =
                isActive
        };
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"membership-unit-"
                    + $"{Guid.NewGuid():N}")
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static async Task<Client>
        SeedClientAsync(
            ApplicationDbContext context)
    {
        var user =
            CreateUser(
                "client@test.local",
                "Test",
                "Client");

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

        return client;
    }

    private static async Task<Therapist>
        SeedTherapistAsync(
            ApplicationDbContext context,
            bool blocked = false)
    {
        var user =
            CreateUser(
                $"therapist-{Guid.NewGuid():N}@test.local",
                "Test",
                "Therapist");

        user.IsBlocked =
            blocked;

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

                PricePerSession =
                    50m,

                HourlyRate =
                    50m,

                ExperienceYears =
                    5,

                Country =
                    "Bosnia and Herzegovina",

                City =
                    "Mostar",

                Address =
                    "Test",

                Education =
                    "Test"
            };

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        return therapist;
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

            CreatedAtUtc =
                DateTime.UtcNow
        };
    }
}
