using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Interfaces;
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

public sealed class AutomaticAppointmentStatusTests
{
    private static readonly DateTime Now = new(2026, 10, 28, 10, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(AppointmentStatus.Accepted, -1, AppointmentStatus.Completed)]
    [InlineData(AppointmentStatus.Accepted, 0, AppointmentStatus.Completed)]
    [InlineData(AppointmentStatus.Accepted, 1, AppointmentStatus.Accepted)]
    [InlineData(AppointmentStatus.Pending, -1, AppointmentStatus.Rejected)]
    [InlineData(AppointmentStatus.Pending, 0, AppointmentStatus.Rejected)]
    [InlineData(AppointmentStatus.Pending, 1, AppointmentStatus.Pending)]
    [InlineData(AppointmentStatus.Completed, -1, AppointmentStatus.Completed)]
    [InlineData(AppointmentStatus.Cancelled, -1, AppointmentStatus.Cancelled)]
    [InlineData(AppointmentStatus.Rejected, -1, AppointmentStatus.Rejected)]
    public async Task Expiration_UsesEndUtcAndOnlyValidTransitions(
        AppointmentStatus before, int endMinutes, AppointmentStatus after)
    {
        await using var db = Context();
        var appointment = await Seed(db, before, Now.AddMinutes(endMinutes));
        var membership = new Mock<IMembershipService>();
        var outbox = new CapturingOutbox();
        var service = Service(db, membership, outbox, Now);

        await service.GetMyAppointmentsAsync(appointment.Client.UserId, 1, 20, null, null, null);
        await service.GetMyAppointmentsAsync(appointment.Client.UserId, 1, 20, null, null, null);

        Assert.Equal(after, appointment.Status);
        var changed = before != after;
        Assert.Equal(changed ? 1 : 0, await db.AppointmentStatusAudits.CountAsync());
        Assert.Equal(changed ? 1 : 0, outbox.Events.Count);
        membership.Verify(x => x.FinalizeAppointmentUsageAsync(appointment.Id, It.IsAny<string>()),
            after == AppointmentStatus.Completed && before == AppointmentStatus.Accepted ? Times.Once() : Times.Never());
        membership.Verify(x => x.HandleAppointmentCancellationAsync(It.IsAny<int>(), It.IsAny<string>(), It.IsAny<bool>()), Times.Never());
        if (!changed) return;

        var audit = await db.AppointmentStatusAudits.SingleAsync();
        Assert.Equal(before, audit.PreviousStatus);
        Assert.Equal(after, audit.NewStatus);
        Assert.Null(audit.ChangedByUserId);
        Assert.Equal(Now, audit.ChangedAtUtc);
        if (before == AppointmentStatus.Pending)
        {
            Assert.Equal("AutomaticExpiration", audit.Action);
            Assert.Contains("therapist did not respond", audit.Reason);
            var rejected = Assert.IsType<AppointmentRejectedEvent>(Assert.Single(outbox.Events));
            Assert.Equal(audit.Reason, rejected.Reason);
        }
        else
        {
            Assert.Equal("AutomaticCompletion", audit.Action);
            Assert.Null(Assert.IsType<AppointmentCompletedEvent>(Assert.Single(outbox.Events)).CompletedByUserId);
        }
    }

    [Theory]
    [InlineData(3, 29)]
    [InlineData(10, 25)]
    public async Task Expiration_IsBasedOnUtcEvenOnDstTransition(int month, int day)
    {
        await using var db = Context();
        var now = new DateTime(2026, month, day, 1, 0, 0, DateTimeKind.Utc);
        var appointment = await Seed(db, AppointmentStatus.Accepted, now);
        await Service(db, new Mock<IMembershipService>(), new CapturingOutbox(), now)
            .GetMyAppointmentsAsync(appointment.Client.UserId, 1, 20, null, null, null);
        Assert.Equal(AppointmentStatus.Completed, appointment.Status);
    }

    private static ApplicationDbContext Context() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase($"automatic-status-{Guid.NewGuid():N}").Options);

    private static AppointmentService Service(ApplicationDbContext db, Mock<IMembershipService> membership,
        CapturingOutbox outbox, DateTime now) => new(db, Mock.Of<IPaymentService>(), membership.Object,
            new ApplicationMetrics(), Mock.Of<IIntegrationEventPublisher>(), outbox, new FrozenClock(now));

    private static async Task<Appointment> Seed(ApplicationDbContext db, AppointmentStatus status, DateTime end)
    {
        ApplicationUser User() => new() { UserName = Guid.NewGuid().ToString(), FirstName = "Test", LastName = "User" };
        var appointment = new Appointment
        {
            Client = new Client { User = User() },
            Therapist = new Therapist { User = User(), Biography = "Biography", Specialization = "Test" },
            StartUtc = end.AddHours(-1), EndUtc = end, AppointmentDateUtc = end.AddHours(-1), Status = status
        };
        db.Add(appointment);
        await db.SaveChangesAsync();
        return appointment;
    }

    private sealed class FrozenClock(DateTime utc) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(utc);
    }

    private sealed class CapturingOutbox : IOutboxWriter
    {
        public List<IntegrationEvent> Events { get; } = [];
        public Task EnqueueAsync<TEvent>(TEvent integrationEvent, string routingKey,
            CancellationToken cancellationToken = default, string? idempotencyKey = null) where TEvent : IntegrationEvent
        {
            Events.Add(integrationEvent);
            return Task.CompletedTask;
        }
    }
}
