using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Shared.Observability;
using Moq;

namespace MindBloom.UnitTests.Appointments;

public sealed class ManualAppointmentCompletionTests
{
    [Theory]
    [InlineData(1)]
    [InlineData(5)]
    [InlineData(86400)]
    [InlineData(604800)]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-604800)]
    public Task Completion_UsesExactUtcEndBoundary(int seconds) => Check(
        new DateTime(2026, 7, 6, 10, 0, 0, DateTimeKind.Utc), seconds, AppointmentStatus.Accepted);

    [Theory]
    [InlineData(1, 12, 1)]
    [InlineData(1, 12, 0)]
    [InlineData(3, 29, 1)]
    [InlineData(3, 29, 0)]
    [InlineData(10, 25, 1)]
    [InlineData(10, 25, 0)]
    public Task Completion_DoesNotDependOnSeasonOrDst(int month, int day, int seconds) => Check(
        new DateTime(2026, month, day, 1, 0, 0, DateTimeKind.Utc), seconds, AppointmentStatus.Accepted);

    [Theory]
    [InlineData(AppointmentStatus.Pending)]
    [InlineData(AppointmentStatus.Rejected)]
    [InlineData(AppointmentStatus.Cancelled)]
    [InlineData(AppointmentStatus.Completed)]
    public Task Completion_DoesNotBypassTransitionRules(AppointmentStatus status) => Check(
        new DateTime(2026, 7, 6, 10, 0, 0, DateTimeKind.Utc), -1, status);

    private static async Task Check(DateTime now, int seconds, AppointmentStatus status)
    {
        await using var db = new ApplicationDbContext(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase($"manual-completion-{Guid.NewGuid():N}").Options);
        ApplicationUser User() => new() { UserName = Guid.NewGuid().ToString(), FirstName = "Test", LastName = "User" };
        var end = now.AddSeconds(seconds);
        var appointment = new Appointment
        {
            Client = new Client { User = User() },
            Therapist = new Therapist { User = User(), Biography = "Biography", Specialization = "Test" },
            StartUtc = end.AddHours(-1), EndUtc = end, AppointmentDateUtc = end.AddHours(-1), Status = status
        };
        db.Add(appointment);
        await db.SaveChangesAsync();
        var membership = new Mock<IMembershipService>();
        var publisher = new Mock<IIntegrationEventPublisher>();
        var outbox = new Mock<IOutboxWriter>(MockBehavior.Strict);
        var service = new AppointmentService(db, Mock.Of<IPaymentService>(), membership.Object,
            new ApplicationMetrics(), publisher.Object, outbox.Object, new FrozenClock(now));
        var request = new UpdateAppointmentStatusDto { AppointmentId = appointment.Id, Status = AppointmentStatus.Completed };
        var allowed = status == AppointmentStatus.Accepted && seconds <= 0;

        if (!allowed)
        {
            var error = await Assert.ThrowsAsync<BusinessException>(() => service.UpdateStatusAsync(appointment.Therapist.UserId, request));
            Assert.Contains(status == AppointmentStatus.Accepted ? "scheduled end time" : "not allowed", error.Message);
            Assert.Equal(status, appointment.Status);
            Assert.Empty(await db.AppointmentStatusAudits.ToListAsync());
            Assert.False(db.ChangeTracker.HasChanges());
            membership.VerifyNoOtherCalls();
            publisher.VerifyNoOtherCalls();
        }
        else
        {
            await service.UpdateStatusAsync(appointment.Therapist.UserId, request);
            Assert.Equal(AppointmentStatus.Completed, appointment.Status);
            var audit = Assert.Single(await db.AppointmentStatusAudits.ToListAsync());
            Assert.Equal(AppointmentStatus.Accepted, audit.PreviousStatus);
            Assert.Equal(appointment.Therapist.UserId, audit.ChangedByUserId);
            membership.Verify(x => x.FinalizeAppointmentUsageAsync(appointment.Id, It.IsAny<string>()), Times.Once);
            publisher.Verify(x => x.PublishAsync(It.IsAny<AppointmentCompletedEvent>(),
                It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Once);
            await Assert.ThrowsAsync<BusinessException>(() => service.UpdateStatusAsync(appointment.Therapist.UserId, request));
            Assert.Single(await db.AppointmentStatusAudits.ToListAsync());
            membership.VerifyNoOtherCalls();
            publisher.VerifyNoOtherCalls();
        }
        Assert.Equal(end, appointment.EndUtc);
        outbox.VerifyNoOtherCalls();
    }

    private sealed class FrozenClock(DateTime utc) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(utc);
    }
}
