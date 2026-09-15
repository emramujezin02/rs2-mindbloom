using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Options;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Workshops.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Configuration;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Workshops;

public sealed class WorkshopServiceTests
{
    [Fact]
    public async Task RegisterAsync_WhenClientDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10);

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<NotFoundException>(
            () =>
                service.RegisterAsync(
                    999,
                    100));

        Assert.Empty(
            await context
                .WorkshopRegistrations
                .ToListAsync());
    }

    [Fact]
    public async Task RegisterAsync_WhenWorkshopDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        var service =
            CreateService(
                context);

        await Assert.ThrowsAsync<NotFoundException>(
            () =>
                service.RegisterAsync(
                    10,
                    999));
    }

    [Fact]
    public async Task RegisterAsync_WhenWorkshopIsNotScheduled_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10,
            status:
                WorkshopStatus.Cancelled);

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.RegisterAsync(
                        10,
                        100));

        Assert.Contains(
            "scheduled",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.Empty(
            await context
                .WorkshopRegistrations
                .ToListAsync());
    }

    [Fact]
    public async Task RegisterAsync_WhenRegistrationDeadlinePassed_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10,
            registrationDeadlineUtc:
                DateTime.UtcNow
                    .AddMinutes(-5));

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.RegisterAsync(
                        10,
                        100));

        Assert.Contains(
            "deadline",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.Empty(
            await context
                .WorkshopRegistrations
                .ToListAsync());
    }

    [Fact]
    public async Task RegisterAsync_WhenClientIsAlreadyRegistered_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10);

        context.WorkshopRegistrations.Add(
            new WorkshopRegistration
            {
                Id = 200,
                WorkshopId = 100,
                ClientId = 20,
                Status =
                    WorkshopRegistrationStatus
                        .Registered,
                RegisteredAtUtc =
                    DateTime.UtcNow
                        .AddDays(-1)
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.RegisterAsync(
                        10,
                        100));

        Assert.Contains(
            "already registered",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.Equal(
            1,
            await context
                .WorkshopRegistrations
                .CountAsync());
    }

    [Fact]
    public async Task RegisterAsync_WhenWorkshopIsFull_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedClientAsync(
            context,
            userId: 11,
            clientId: 21);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 1);

        context.WorkshopRegistrations.Add(
            new WorkshopRegistration
            {
                Id = 200,
                WorkshopId = 100,
                ClientId = 21,
                Status =
                    WorkshopRegistrationStatus
                        .Registered,
                RegisteredAtUtc =
                    DateTime.UtcNow
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.RegisterAsync(
                        10,
                        100));

        Assert.Contains(
            "maximum capacity",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.DoesNotContain(
            await context
                .WorkshopRegistrations
                .ToListAsync(),
            x =>
                x.ClientId == 20);
    }

    [Fact]
    public async Task RegisterAsync_WhenRequestIsValid_CreatesRegistration()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedOrganizerAsync(
            context,
            userId: 50);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10,
            organizerUserId: 50);

        var notificationMock =
            CreateNotificationMock();

        var service =
            CreateService(
                context,
                notificationMock);

        await service.RegisterAsync(
            10,
            100);

        var registration =
            await context
                .WorkshopRegistrations
                .SingleAsync();

        Assert.Equal(
            100,
            registration.WorkshopId);

        Assert.Equal(
            20,
            registration.ClientId);

        Assert.Equal(
            WorkshopRegistrationStatus
                .Registered,
            registration.Status);

        Assert.False(
            registration.IsDeleted);

        Assert.Null(
            registration.CancelledAtUtc);

        notificationMock.Verify(
            x =>
                x.PublishAsync(
                    10,
                    "Workshop registration confirmed",
                    It.Is<string>(
                        message =>
                            message.Contains(
                                "Test Workshop")),
                    null,
                    NotificationActionType.Workshop,
                    100,
                    true,
                    true,
                    null,
                    It.IsAny<CancellationToken>()),
            Times.Once);
    }

    [Fact]
    public async Task RegisterAsync_WhenPreviouslyCancelled_ReactivatesExistingRegistration()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10);

        context.WorkshopRegistrations.Add(
            new WorkshopRegistration
            {
                Id = 200,
                WorkshopId = 100,
                ClientId = 20,
                Status =
                    WorkshopRegistrationStatus
                        .Cancelled,
                RegisteredAtUtc =
                    DateTime.UtcNow
                        .AddDays(-5),
                CancelledAtUtc =
                    DateTime.UtcNow
                        .AddDays(-2),
                IsDeleted = true
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service.RegisterAsync(
            10,
            100);

        var registrations =
            await context
                .WorkshopRegistrations
                .ToListAsync();

        Assert.Single(
            registrations);

        var registration =
            registrations[0];

        Assert.Equal(
            WorkshopRegistrationStatus
                .Registered,
            registration.Status);

        Assert.False(
            registration.IsDeleted);

        Assert.Null(
            registration.CancelledAtUtc);
    }

    [Fact]
    public async Task CancelRegistrationAsync_WhenWorkshopAlreadyStarted_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10,
            startUtc:
                DateTime.UtcNow
                    .AddHours(-1),
            endUtc:
                DateTime.UtcNow
                    .AddHours(1));

        context.WorkshopRegistrations.Add(
            new WorkshopRegistration
            {
                Id = 200,
                WorkshopId = 100,
                ClientId = 20,
                Status =
                    WorkshopRegistrationStatus
                        .Registered,
                RegisteredAtUtc =
                    DateTime.UtcNow
                        .AddDays(-1)
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.CancelRegistrationAsync(
                        10,
                        100));

        Assert.Contains(
            "started",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        var registration =
            await context
                .WorkshopRegistrations
                .SingleAsync();

        Assert.Equal(
            WorkshopRegistrationStatus
                .Registered,
            registration.Status);
    }

    [Fact]
    public async Task CancelRegistrationAsync_WhenRegistrationExists_CancelsRegistration()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10);

        context.WorkshopRegistrations.Add(
            new WorkshopRegistration
            {
                Id = 200,
                WorkshopId = 100,
                ClientId = 20,
                Status =
                    WorkshopRegistrationStatus
                        .Registered,
                RegisteredAtUtc =
                    DateTime.UtcNow
                        .AddDays(-1)
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        await service.CancelRegistrationAsync(
            10,
            100);

        var registration =
            await context
                .WorkshopRegistrations
                .SingleAsync();

        Assert.Equal(
            WorkshopRegistrationStatus
                .Cancelled,
            registration.Status);

        Assert.NotNull(
            registration.CancelledAtUtc);
    }

    [Fact]
    public async Task DeleteAsync_WhenWorkshopHasActiveRegistrations_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedClientAsync(
            context,
            userId: 10,
            clientId: 20);

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10);

        context.WorkshopRegistrations.Add(
            new WorkshopRegistration
            {
                Id = 200,
                WorkshopId = 100,
                ClientId = 20,
                Status =
                    WorkshopRegistrationStatus
                        .Registered,
                RegisteredAtUtc =
                    DateTime.UtcNow
            });

        await context.SaveChangesAsync();

        var service =
            CreateService(
                context);

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.DeleteAsync(
                        999,
                        true,
                        100));

        Assert.Contains(
            "active registrations",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        var workshop =
            await context.Workshops
                .SingleAsync(
                    x => x.Id == 100);

        Assert.False(
            workshop.IsDeleted);
    }

    [Fact]
    public async Task UpdateStatusAsync_WhenCancellingWithoutReason_ThrowsBadRequestException()
    {
        await using var context =
            CreateContext();

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10);

        var service =
            CreateService(
                context);

        var request =
            new UpdateWorkshopStatusDto
            {
                Status =
                    WorkshopStatus.Cancelled,
                Reason = null
            };

        var exception =
            await Assert.ThrowsAsync<BadRequestException>(
                () =>
                    service.UpdateStatusAsync(
                        999,
                        true,
                        100,
                        request));

        Assert.Contains(
            "reason",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        var workshop =
            await context.Workshops
                .SingleAsync(
                    x => x.Id == 100);

        Assert.Equal(
            WorkshopStatus.Scheduled,
            workshop.Status);
    }

    [Fact]
    public async Task UpdateStatusAsync_WhenCompletingBeforeEndTime_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10,
            startUtc:
                DateTime.UtcNow
                    .AddMinutes(-30),
            endUtc:
                DateTime.UtcNow
                    .AddHours(1));

        var service =
            CreateService(
                context);

        var request =
            new UpdateWorkshopStatusDto
            {
                Status =
                    WorkshopStatus.Completed
            };

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.UpdateStatusAsync(
                        999,
                        true,
                        100,
                        request));

        Assert.Contains(
            "before",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        var workshop =
            await context.Workshops
                .SingleAsync(
                    x => x.Id == 100);

        Assert.Equal(
            WorkshopStatus.Scheduled,
            workshop.Status);
    }

    [Fact]
    public async Task UpdateStatusAsync_WhenStatusIsAlreadySelected_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        await SeedWorkshopAsync(
            context,
            workshopId: 100,
            capacity: 10);

        var service =
            CreateService(
                context);

        var request =
            new UpdateWorkshopStatusDto
            {
                Status =
                    WorkshopStatus.Scheduled
            };

        var exception =
            await Assert.ThrowsAsync<BusinessException>(
                () =>
                    service.UpdateStatusAsync(
                        999,
                        true,
                        100,
                        request));

        Assert.Contains(
            "already",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);
    }

    private static WorkshopService
        CreateService(
            ApplicationDbContext context,
            Mock<IBusinessNotificationService>?
                notificationMock = null)
    {
        notificationMock ??=
            CreateNotificationMock();

        var environmentMock =
            new Mock<IWebHostEnvironment>();

        var integrationEventPublisherMock =
            new Mock<
                IIntegrationEventPublisher>();

        var outboxWriterMock =
            new Mock<IOutboxWriter>();

        return new WorkshopService(
            context,
            notificationMock.Object,
            environmentMock.Object,
            Options.Create(
                new UploadSettings()),
            integrationEventPublisherMock.Object,
            outboxWriterMock.Object);
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    Guid.NewGuid().ToString())
                .ConfigureWarnings(
                    warnings =>
                        warnings.Ignore(
                            InMemoryEventId
                                .TransactionIgnoredWarning))
                .Options;

        return new ApplicationDbContext(
            options);
    }

    private static Mock<
        IBusinessNotificationService>
        CreateNotificationMock()
    {
        var mock =
            new Mock<
                IBusinessNotificationService>();

        mock.Setup(
                x =>
                    x.PublishAsync(
                        It.IsAny<int>(),
                        It.IsAny<string>(),
                        It.IsAny<string>(),
                        It.IsAny<int?>(),
                        It.IsAny<NotificationActionType>(),
                        It.IsAny<int?>(),
                        It.IsAny<bool>(),
                        It.IsAny<bool>(),
                        It.IsAny<Guid?>(),
                        It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        return mock;
    }

    private static async Task
        SeedOrganizerAsync(
            ApplicationDbContext context,
            int userId)
    {
        if (await context.Users.AnyAsync(
                x => x.Id == userId))
        {
            return;
        }

        context.Users.Add(
            new ApplicationUser
            {
                Id = userId,
                UserName =
                    $"organizer{userId}@test.com",
                Email =
                    $"organizer{userId}@test.com",
                FirstName = "Workshop",
                LastName = "Organizer",
                DateOfBirth =
                    new DateTime(
                        1990,
                        1,
                        1),
                CreatedAtUtc =
                    DateTime.UtcNow,
                IsActive = true
            });

        await context.SaveChangesAsync();
    }

    private static async Task<Client>
        SeedClientAsync(
            ApplicationDbContext context,
            int userId,
            int clientId)
    {
        var user =
            new ApplicationUser
            {
                Id = userId,
                UserName =
                    $"client{userId}@test.com",
                Email =
                    $"client{userId}@test.com",
                FirstName = "Client",
                LastName =
                    userId.ToString(),
                DateOfBirth =
                    new DateTime(
                        2000,
                        1,
                        1),
                CreatedAtUtc =
                    DateTime.UtcNow,
                IsActive = true
            };

        var client =
            new Client
            {
                Id = clientId,
                UserId = userId,
                User = user
            };

        context.Users.Add(user);

        context.Clients.Add(client);

        await context.SaveChangesAsync();

        return client;
    }

    private static async Task<Workshop>
        SeedWorkshopAsync(
            ApplicationDbContext context,
            int workshopId,
            int capacity,
            WorkshopStatus status =
                WorkshopStatus.Scheduled,
            int organizerUserId = 50,
            DateTime? registrationDeadlineUtc =
                null,
            DateTime? startUtc = null,
            DateTime? endUtc = null)
    {
        if (!await context.Users.AnyAsync(
                x => x.Id ==
                    organizerUserId))
        {
            await SeedOrganizerAsync(
                context,
                organizerUserId);
        }

        var resolvedStart =
            startUtc ??
            DateTime.UtcNow
                .AddDays(5);

        var resolvedEnd =
            endUtc ??
            resolvedStart
                .AddHours(2);

        var workshop =
            new Workshop
            {
                Id = workshopId,
                Title =
                    "Test Workshop",
                Description =
                    "Workshop used for unit testing.",
                StartUtc =
                    resolvedStart,
                EndUtc =
                    resolvedEnd,
                Type =
                    WorkshopType.Online,
                OnlineLink =
                    "https://example.com/workshop",
                Capacity =
                    capacity,
                Price = 20m,
                Status =
                    status,
                OrganizerUserId =
                    organizerUserId,
                RegistrationDeadlineUtc =
                    registrationDeadlineUtc ??
                    DateTime.UtcNow
                        .AddDays(3)
            };

        context.Workshops.Add(
            workshop);

        await context.SaveChangesAsync();

        return workshop;
    }
}