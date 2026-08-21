using Microsoft.EntityFrameworkCore;
using Moq;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.Shared.Observability;

namespace MindBloom.UnitTests.Appointments;

public sealed class AppointmentServiceTests
{
    [Fact]
    public async Task
        UpdateStatusAsync_WhenTherapistDoesNotExist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var service =
            CreateService(context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.UpdateStatusAsync(
                    999,
                    new UpdateAppointmentStatusDto
                    {
                        AppointmentId = 1,
                        Status =
                            AppointmentStatus.Accepted
                    }));
    }

    [Fact]
    public async Task
        UpdateStatusAsync_WhenAppointmentDoesNotBelongToTherapist_ThrowsNotFoundException()
    {
        await using var context =
            CreateContext();

        var firstTherapist =
            await SeedTherapistAsync(
                context,
                "first@test.local");

        var secondTherapist =
            await SeedTherapistAsync(
                context,
                "second@test.local");

        var client =
            await SeedClientAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                firstTherapist.Id,
                AppointmentStatus.Pending);

        var service =
            CreateService(context);

        await Assert.ThrowsAsync<
            NotFoundException>(
            () =>
                service.UpdateStatusAsync(
                    secondTherapist.UserId,
                    new UpdateAppointmentStatusDto
                    {
                        AppointmentId =
                            appointment.Id,

                        Status =
                            AppointmentStatus.Accepted
                    }));
    }

    [Fact]
    public async Task
        UpdateStatusAsync_WhenPendingChangesToCompleted_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        var client =
            await SeedClientAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Pending);

        var service =
            CreateService(context);

        var exception =
            await Assert.ThrowsAsync<
                BusinessException>(
                () =>
                    service.UpdateStatusAsync(
                        therapist.UserId,
                        new UpdateAppointmentStatusDto
                        {
                            AppointmentId =
                                appointment.Id,

                            Status =
                                AppointmentStatus.Completed
                        }));

        Assert.Contains(
            "not allowed",
            exception.Message,
            StringComparison.OrdinalIgnoreCase);

        Assert.Equal(
            AppointmentStatus.Pending,
            appointment.Status);
    }

    [Fact]
    public async Task
        UpdateStatusAsync_WhenStatusDoesNotChange_ThrowsBusinessException()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        var client =
            await SeedClientAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Pending);

        var service =
            CreateService(context);

        await Assert.ThrowsAsync<
            BusinessException>(
            () =>
                service.UpdateStatusAsync(
                    therapist.UserId,
                    new UpdateAppointmentStatusDto
                    {
                        AppointmentId =
                            appointment.Id,

                        Status =
                            AppointmentStatus.Pending
                    }));
    }

    [Fact]
    public async Task
        UpdateStatusAsync_WhenPendingChangesToAccepted_UpdatesStatusAndCreatesAudit()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        var client =
            await SeedClientAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Pending);

        var publisher =
            new Mock<
                IIntegrationEventPublisher>();

        publisher
            .Setup(x =>
                x.PublishAsync(
                    It.IsAny<
                        MindBloom.Messaging.Contracts.Common.IntegrationEvent>(),
                    It.IsAny<string>(),
                    It.IsAny<CancellationToken>()))
            .Returns(
                Task.CompletedTask);

        var service =
            CreateService(
                context,
                integrationEventPublisher:
                    publisher.Object);

        await service.UpdateStatusAsync(
            therapist.UserId,
            new UpdateAppointmentStatusDto
            {
                AppointmentId =
                    appointment.Id,

                Status =
                    AppointmentStatus.Accepted
            });

        Assert.Equal(
            AppointmentStatus.Accepted,
            appointment.Status);

        var audit =
            await context
                .AppointmentStatusAudits
                .SingleAsync();

        Assert.Equal(
            AppointmentStatus.Pending,
            audit.PreviousStatus);

        Assert.Equal(
            AppointmentStatus.Accepted,
            audit.NewStatus);

        Assert.Equal(
            "TherapistStatusChange",
            audit.Action);
    }

    [Fact]
    public async Task
        UpdateStatusAsync_WhenAcceptedChangesToCompleted_FinalizesMembershipUsage()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        var client =
            await SeedClientAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Accepted);

        var membershipService =
            new Mock<
                IMembershipService>();

        membershipService
            .Setup(x =>
                x.FinalizeAppointmentUsageAsync(
                    appointment.Id,
                    It.IsAny<string>()))
            .Returns(
                Task.CompletedTask);

        var publisher =
            new Mock<
                IIntegrationEventPublisher>();

        publisher
            .Setup(x =>
                x.PublishAsync(
                    It.IsAny<
                        MindBloom.Messaging.Contracts.Common.IntegrationEvent>(),
                    It.IsAny<string>(),
                    It.IsAny<CancellationToken>()))
            .Returns(
                Task.CompletedTask);

        var service =
            CreateService(
                context,
                membershipService:
                    membershipService.Object,
                integrationEventPublisher:
                    publisher.Object);

        await service.UpdateStatusAsync(
            therapist.UserId,
            new UpdateAppointmentStatusDto
            {
                AppointmentId =
                    appointment.Id,

                Status =
                    AppointmentStatus.Completed
            });

        Assert.Equal(
            AppointmentStatus.Completed,
            appointment.Status);

        membershipService.Verify(
            x =>
                x.FinalizeAppointmentUsageAsync(
                    appointment.Id,
                    It.Is<string>(
                        value =>
                            value.Contains(
                                "completed",
                                StringComparison
                                    .OrdinalIgnoreCase))),
            Times.Once);
    }

    [Fact]
    public async Task
        UpdateStatusAsync_WhenPendingIsRejected_RestoresMembershipUsage()
    {
        await using var context =
            CreateContext();

        var therapist =
            await SeedTherapistAsync(
                context);

        var client =
            await SeedClientAsync(
                context);

        var appointment =
            await SeedAppointmentAsync(
                context,
                client.Id,
                therapist.Id,
                AppointmentStatus.Pending);

        var membershipService =
            new Mock<
                IMembershipService>();

        membershipService
            .Setup(x =>
                x.HandleAppointmentCancellationAsync(
                    appointment.Id,
                    It.IsAny<string>(),
                    true))
            .Returns(
                Task.CompletedTask);

        var publisher =
            new Mock<
                IIntegrationEventPublisher>();

        publisher
            .Setup(x =>
                x.PublishAsync(
                    It.IsAny<
                        MindBloom.Messaging.Contracts.Common.IntegrationEvent>(),
                    It.IsAny<string>(),
                    It.IsAny<CancellationToken>()))
            .Returns(
                Task.CompletedTask);

        var service =
            CreateService(
                context,
                membershipService:
                    membershipService.Object,
                integrationEventPublisher:
                    publisher.Object);

        await service.UpdateStatusAsync(
            therapist.UserId,
            new UpdateAppointmentStatusDto
            {
                AppointmentId =
                    appointment.Id,

                Status =
                    AppointmentStatus.Rejected
            });

        Assert.Equal(
            AppointmentStatus.Rejected,
            appointment.Status);

        membershipService.Verify(
            x =>
                x.HandleAppointmentCancellationAsync(
                    appointment.Id,
                    It.IsAny<string>(),
                    true),
            Times.Once);
    }

    private static AppointmentService
        CreateService(
            ApplicationDbContext context,
            IMembershipService?
                membershipService = null,
            IIntegrationEventPublisher?
                integrationEventPublisher = null)
    {
        var paymentService =
            new Mock<IPaymentService>();

        var membership =
            membershipService ??
            new Mock<IMembershipService>()
                .Object;

        var publisher =
            integrationEventPublisher ??
            new Mock<
                IIntegrationEventPublisher>()
                .Object;

        var outbox =
            new Mock<
                IOutboxWriter>();

        return new AppointmentService(
            context,
            paymentService.Object,
            membership,
            new ApplicationMetrics(),
            publisher,
            outbox.Object);
    }

    private static ApplicationDbContext
        CreateContext()
    {
        var options =
            new DbContextOptionsBuilder<
                    ApplicationDbContext>()
                .UseInMemoryDatabase(
                    $"appointment-unit-"
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
                "Client",
                "User");

        context.Users.Add(user);

        await context.SaveChangesAsync();

        var client =
            new Client
            {
                UserId =
                    user.Id
            };

        context.Clients.Add(client);

        await context.SaveChangesAsync();

        return client;
    }

    private static async Task<Therapist>
        SeedTherapistAsync(
            ApplicationDbContext context,
            string email =
                "therapist@test.local")
    {
        var user =
            CreateUser(
                email,
                "Test",
                "Therapist");

        context.Users.Add(user);

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
                    "Test address",

                Education =
                    "Test education"
            };

        context.Therapists.Add(
            therapist);

        await context.SaveChangesAsync();

        return therapist;
    }

    private static async Task<Appointment>
        SeedAppointmentAsync(
            ApplicationDbContext context,
            int clientId,
            int therapistId,
            AppointmentStatus status)
    {
        var appointment =
            new Appointment
            {
                ClientId =
                    clientId,

                TherapistId =
                    therapistId,

                AppointmentDateUtc =
                    DateTime.UtcNow
                        .AddDays(2),

                StartUtc =
                    DateTime.UtcNow
                        .AddDays(2),

                EndUtc =
                    DateTime.UtcNow
                        .AddDays(2)
                        .AddHours(1),

                Status =
                    status,

                Price =
                    50m,

                Type =
                    AppointmentType.Online,

                IsPaid =
                    false
            };

        context.Appointments.Add(
            appointment);

        await context.SaveChangesAsync();

        return appointment;
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