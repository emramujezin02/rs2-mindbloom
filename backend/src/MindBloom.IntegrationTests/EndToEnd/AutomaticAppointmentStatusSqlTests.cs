using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.Shared.Constants;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class AutomaticAppointmentStatusSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    private static readonly DateTime Now = DateTime.UtcNow;

    [Theory]
    [InlineData(AppointmentStatus.Accepted, -1, AppointmentStatus.Completed)]
    [InlineData(AppointmentStatus.Accepted, 0, AppointmentStatus.Completed)]
    [InlineData(AppointmentStatus.Accepted, 1, AppointmentStatus.Accepted)]
    [InlineData(AppointmentStatus.Pending, -1, AppointmentStatus.Rejected)]
    [InlineData(AppointmentStatus.Pending, 0, AppointmentStatus.Rejected)]
    [InlineData(AppointmentStatus.Pending, 1, AppointmentStatus.Pending)]
    [InlineData(AppointmentStatus.Completed, -1, AppointmentStatus.Completed)]
    [InlineData(AppointmentStatus.Rejected, -1, AppointmentStatus.Rejected)]
    [InlineData(AppointmentStatus.Cancelled, -1, AppointmentStatus.Cancelled)]
    public async Task AutomaticStatus_IsAtomicAndIdempotentWithRealMembership(
        AppointmentStatus before, int endDays, AppointmentStatus after)
    {
        var s = await Seed(before, Now.AddDays(endDays));
        await Run(s);
        await Run(s);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(after, (await db.Appointments.FindAsync(s.Id))!.Status);
        var audits = await db.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).ToListAsync();
        var events = await Events(db, s.Id);
        var changed = before != after;
        Assert.Equal(changed ? 1 : 0, audits.Count);
        Assert.Equal(changed ? 1 : 0, events.Count);
        if (changed)
        {
            var audit = Assert.Single(audits);
            Assert.Equal(before, audit.PreviousStatus);
            Assert.Equal(after, audit.NewStatus);
            Assert.Null(audit.ChangedByUserId);
            Assert.Equal(Now, audit.ChangedAtUtc);
            var details = await scope.ServiceProvider.GetRequiredService<IAdminService>().GetAppointmentDetailsAsync(s.Id);
            var displayedAudit = Assert.Single(details.AuditHistory);
            Assert.Null(displayedAudit.ChangedByUserId);
            Assert.Equal("System", displayedAudit.ChangedByUserName);
            Assert.Equal(string.Empty, displayedAudit.ChangedByUserEmail);
            Assert.Equal(after == AppointmentStatus.Completed ? IntegrationEventRoutingKeys.AppointmentCompleted
                : IntegrationEventRoutingKeys.AppointmentRejected, Assert.Single(events).RoutingKey);
            if (before == AppointmentStatus.Pending)
            {
                Assert.Contains("therapist did not respond", audit.Reason);
                Assert.Contains(audit.Reason!, events[0].PayloadJson);
            }
        }
        var usage = await db.MembershipUsages.SingleOrDefaultAsync(x => x.AppointmentId == s.Id);
        if (before == AppointmentStatus.Accepted)
        {
            Assert.NotNull(usage);
            Assert.Equal(changed ? MembershipUsageStatus.Consumed : MembershipUsageStatus.Reserved, usage.Status);
            Assert.Equal(2, (await db.ClientMemberships.FindAsync(s.MembershipId))!.RemainingSessions);
        }
        else
        {
            Assert.Null(usage);
            Assert.Equal(3, (await db.ClientMemberships.FindAsync(s.MembershipId))!.RemainingSessions);
        }
    }

    [Theory]
    [InlineData(AppointmentStatus.Pending, HttpStatusCode.Conflict)]
    [InlineData(AppointmentStatus.Accepted, HttpStatusCode.Created)]
    public async Task ReviewHttp_AfterAutomaticProcessing_RequiresActualCompletedSession(
        AppointmentStatus before, HttpStatusCode expected)
    {
        var s = await Seed(before, Now.AddDays(-1));
        using var anonymous = factory.CreateClient();
        anonymous.DefaultRequestHeaders.Add("X-Forwarded-For", $"2001:db8:12::{s.ClientUserId:x}");
        var login = await anonymous.PostAsJsonAsync("/api/Auth/login-2fa", new LoginRequestDto
            { Email = s.Email, Password = "AutomaticTest123!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var auth = await login.Content.ReadFromJsonAsync<Login2FAResponseDto>();
        using var http = factory.CreateBearerClient(auth!.Auth!.Token);
        // Real GET invokes the existing automatic processing path, twice.
        Assert.Equal(HttpStatusCode.OK, (await http.GetAsync("/api/Appointments/mine?pageNumber=1&pageSize=20")).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await http.GetAsync("/api/Appointments/mine?pageNumber=1&pageSize=20")).StatusCode);
        using var response = await http.PostAsJsonAsync("/api/Reviews", new CreateReviewDto
            { AppointmentId = s.Id, Rating = 5, Comment = "Test session review" });
        Assert.Equal(expected, response.StatusCode);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(expected == HttpStatusCode.Created ? 1 : 0,
            await db.Reviews.CountAsync(x => x.AppointmentId == s.Id));
        Assert.Single(await db.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).ToListAsync());
        Assert.Single(await Events(db, s.Id));
    }

    [Theory]
    [InlineData(AppointmentStatus.Accepted)]
    [InlineData(AppointmentStatus.Pending)]
    public async Task FailureAfterSavingOutbox_RollsBackStatusAuditUsageAndEvent(AppointmentStatus before)
    {
        var s = await Seed(before, Now.AddDays(-1));
        await Assert.ThrowsAsync<InvalidOperationException>(() => Run(s,
            (db, writer) => new FaultingOutbox(db, writer)));
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Assert.Equal(before, (await db.Appointments.FindAsync(s.Id))!.Status);
            Assert.Empty(await db.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).ToListAsync());
            Assert.Empty(await Events(db, s.Id));
            if (before == AppointmentStatus.Accepted)
                Assert.Equal(MembershipUsageStatus.Reserved,
                    (await db.MembershipUsages.SingleAsync(x => x.AppointmentId == s.Id)).Status);
        }
        // Retry succeeds, which also proves release of the failed operation's session lock.
        await Run(s);
        using var verification = factory.Services.CreateScope();
        var verifyDb = verification.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Single(await Events(verifyDb, s.Id));
    }

    [Theory]
    [InlineData(AppointmentStatus.Accepted)]
    [InlineData(AppointmentStatus.Pending)]
    public async Task AuditSqlFailure_RollsBackTheWholeAppointmentOperation(AppointmentStatus before)
    {
        var s = await Seed(before, Now.AddDays(-1));
        await Assert.ThrowsAsync<DbUpdateException>(() => Run(s,
            (db, writer) => new InvalidAuditOutbox(db, writer, s.Id)));
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Assert.Equal(before, (await db.Appointments.FindAsync(s.Id))!.Status);
            Assert.Empty(await db.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).ToListAsync());
            Assert.Empty(await Events(db, s.Id));
            if (before == AppointmentStatus.Accepted)
                Assert.Equal(MembershipUsageStatus.Reserved,
                    (await db.MembershipUsages.SingleAsync(x => x.AppointmentId == s.Id)).Status);
        }
        await Run(s);
    }

    [Fact]
    public async Task BatchFailure_PreservesCommittedItemsAndSafelyRetriesTheFailedItem()
    {
        var first = await Seed(AppointmentStatus.Accepted, Now.AddDays(-1));
        var second = await Seed(AppointmentStatus.Pending, Now.AddDays(-1));
        await Assert.ThrowsAsync<DbUpdateException>(() => Run(first,
            (db, writer) => new InvalidAuditOutbox(db, writer, second.Id)));
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            Assert.Equal(AppointmentStatus.Completed, (await db.Appointments.FindAsync(first.Id))!.Status);
            Assert.Single(await Events(db, first.Id));
            Assert.Equal(AppointmentStatus.Pending, (await db.Appointments.FindAsync(second.Id))!.Status);
            Assert.Empty(await Events(db, second.Id));
            Assert.Empty(await db.AppointmentStatusAudits.Where(x => x.AppointmentId == second.Id).ToListAsync());
        }
        await Run(second);
        using var verification = factory.Services.CreateScope();
        var finalDb = verification.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Single(await Events(finalDb, first.Id));
        Assert.Single(await Events(finalDb, second.Id));
    }

    [Theory]
    [InlineData("accept")]
    [InlineData("reject")]
    [InlineData("cancel")]
    [InlineData("complete")]
    [InlineData("two-jobs")]
    [Trait("Category", "AutomaticStatusConcurrency")]
    public async Task ConcurrentWriters_NeverOverwriteTerminalStatusOrDuplicateCompletion(string operation)
    {
        var initial = operation == "complete" ? AppointmentStatus.Accepted : AppointmentStatus.Pending;
        var s = await Seed(initial, Now.AddDays(-1));
        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        async Task<Exception?> Attempt(Func<Task> action)
        {
            await gate.Task;
            try { await action(); return null; } catch (BusinessException e) { return e; }
        }
        var automatic = Attempt(() => Run(s));
        var other = Attempt(async () =>
        {
            if (operation == "two-jobs") { await Run(s); return; }
            using var scope = factory.Services.CreateScope();
            var service = scope.ServiceProvider.GetRequiredService<IAppointmentService>();
            if (operation == "cancel")
                await service.CancelAppointmentAsync(s.ClientUserId, s.Id, new CancelAppointmentDto { Reason = "Test cancellation" });
            else
                await service.UpdateStatusAsync(s.TherapistUserId, new UpdateAppointmentStatusDto
                {
                    AppointmentId = s.Id,
                    Reason = "Therapist cannot attend",
                    Status = operation == "accept" ? AppointmentStatus.Accepted : operation == "reject"
                        ? AppointmentStatus.Rejected : AppointmentStatus.Completed
                });
        });
        gate.SetResult();
        var failures = await Task.WhenAll(automatic, other);
        Assert.Null(failures[0]);
        using var verification = factory.Services.CreateScope();
        var db = verification.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var audits = await db.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).OrderBy(x => x.Id).ToListAsync();
        var current = initial;
        foreach (var audit in audits)
        {
            Assert.Equal(current, audit.PreviousStatus);
            Assert.True(current == AppointmentStatus.Pending && audit.NewStatus is AppointmentStatus.Accepted or AppointmentStatus.Rejected or AppointmentStatus.Cancelled
                || current == AppointmentStatus.Accepted && audit.NewStatus is AppointmentStatus.Completed or AppointmentStatus.Cancelled);
            current = audit.NewStatus;
        }
        Assert.Equal(current, (await db.Appointments.FindAsync(s.Id))!.Status);
        Assert.Contains(current, new[] { AppointmentStatus.Completed, AppointmentStatus.Rejected, AppointmentStatus.Cancelled });
        var events = await Events(db, s.Id);
        // Acceptance and completion are separate committed transitions since Task 14.
        // Match every event to its audit instead of treating both as duplicate completion.
        var expectedRoutes = audits.Select(a => a.NewStatus switch
        {
            AppointmentStatus.Accepted => IntegrationEventRoutingKeys.AppointmentAccepted,
            AppointmentStatus.Completed => IntegrationEventRoutingKeys.AppointmentCompleted,
            AppointmentStatus.Rejected => IntegrationEventRoutingKeys.AppointmentRejected,
            AppointmentStatus.Cancelled => IntegrationEventRoutingKeys.AppointmentCancelled,
            _ => throw new InvalidOperationException("Unexpected audited transition.")
        }).OrderBy(x => x).ToArray();
        Assert.Equal(expectedRoutes, events.Select(x => x.RoutingKey).OrderBy(x => x).ToArray());
        Assert.All(events.GroupBy(x => x.RoutingKey), group => Assert.Single(group));
        Assert.InRange(events.Count(x => x.RoutingKey == IntegrationEventRoutingKeys.AppointmentCompleted), 0, 1);
        Assert.InRange(audits.Count(x => x.NewStatus == AppointmentStatus.Completed), 0, 1);
        Assert.Equal(initial == AppointmentStatus.Accepted ? 2 : 3,
            (await db.ClientMemberships.FindAsync(s.MembershipId))!.RemainingSessions);
        if (operation == "two-jobs")
        {
            Assert.All(failures, Assert.Null);
            Assert.Single(audits);
            Assert.Single(events);
        }
    }

    [Fact]
    public async Task AcceptanceThenAutomaticCompletion_ProducesOneEventPerCommittedTransition()
    {
        var scenario = await Seed(AppointmentStatus.Pending, Now.AddDays(-1));
        using (var scope = factory.Services.CreateScope())
        {
            await scope.ServiceProvider.GetRequiredService<IAppointmentService>()
                .UpdateStatusAsync(scenario.TherapistUserId, new UpdateAppointmentStatusDto
                {
                    AppointmentId = scenario.Id,
                    Status = AppointmentStatus.Accepted
                });
        }
        await Run(scenario);
        await Run(scenario);
        using var verification = factory.Services.CreateScope();
        var db = verification.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var statuses = await db.AppointmentStatusAudits.Where(x => x.AppointmentId == scenario.Id)
            .OrderBy(x => x.Id).Select(x => x.NewStatus).ToListAsync();
        Assert.Equal(new[] { AppointmentStatus.Accepted, AppointmentStatus.Completed }, statuses);
        var events = await Events(db, scenario.Id);
        Assert.Equal(2, events.Count);
        Assert.Single(events, x => x.RoutingKey == IntegrationEventRoutingKeys.AppointmentAccepted);
        Assert.Single(events, x => x.RoutingKey == IntegrationEventRoutingKeys.AppointmentCompleted);
    }

    private async Task Run(Scenario s, Func<ApplicationDbContext, IOutboxWriter, IOutboxWriter>? decorate = null)
    {
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<ApplicationDbContext>();
        var writer = sp.GetRequiredService<IOutboxWriter>();
        var service = new AppointmentService(db, sp.GetRequiredService<IPaymentService>(),
            sp.GetRequiredService<IMembershipService>(), sp.GetRequiredService<ApplicationMetrics>(),
            sp.GetRequiredService<IIntegrationEventPublisher>(), decorate?.Invoke(db, writer) ?? writer, new FrozenClock());
        await service.GetMyAppointmentsAsync(s.ClientUserId, 1, 20, null, null, null);
    }

    private async Task<Scenario> Seed(AppointmentStatus status, DateTime end)
    {
        var email = $"automatic-{Guid.NewGuid():N}@test.local";
        var clientUserId = await factory.SeedActiveUserAsync(RoleConstants.Client, email, "AutomaticTest123!");
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var client = new Client { UserId = clientUserId };
        var therapist = new Therapist
        {
            User = new ApplicationUser { UserName = Guid.NewGuid().ToString(), FirstName = "Test", LastName = "Therapist", IsActive = true },
            Biography = "Test biography", Specialization = "Test", VerificationStatus = TherapistVerificationStatus.Approved
        };
        var appointment = new Appointment { Client = client, Therapist = therapist, Status = status,
            StartUtc = end.AddHours(-1), EndUtc = end, AppointmentDateUtc = end.AddHours(-1), Type = AppointmentType.Online };
        var membership = new ClientMembership { Client = client, Therapist = therapist,
            TotalSessions = 3, RemainingSessions = status == AppointmentStatus.Accepted ? 2 : 3, IsActive = true };
        db.AddRange(appointment, membership);
        if (status == AppointmentStatus.Accepted)
            db.MembershipUsages.Add(new MembershipUsage { Appointment = appointment, ClientMembership = membership,
                Status = MembershipUsageStatus.Reserved, ReservedAtUtc = Now.AddDays(-2) });
        await db.SaveChangesAsync();
        return new(appointment.Id, clientUserId, therapist.UserId, membership.Id, email);
    }

    private static Task<List<OutboxMessage>> Events(ApplicationDbContext db, int id) => db.OutboxMessages
        .Where(x => x.PayloadJson.Contains("\"appointmentId\":" + id + ",")).ToListAsync();

    private sealed record Scenario(int Id, int ClientUserId, int TherapistUserId, int MembershipId, string Email);
    private sealed class FrozenClock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(Now);
    }
    private sealed class FaultingOutbox(ApplicationDbContext db, IOutboxWriter inner) : IOutboxWriter
    {
        public async Task EnqueueAsync<TEvent>(TEvent integrationEvent, string routingKey,
            CancellationToken cancellationToken = default, string? idempotencyKey = null) where TEvent : IntegrationEvent
        {
            await inner.EnqueueAsync(integrationEvent, routingKey, cancellationToken, idempotencyKey);
            await db.SaveChangesAsync(cancellationToken);
            throw new InvalidOperationException("Injected automatic status outbox failure.");
        }
    }

    private sealed class InvalidAuditOutbox(ApplicationDbContext db, IOutboxWriter inner, int appointmentId) : IOutboxWriter
    {
        public async Task EnqueueAsync<TEvent>(TEvent integrationEvent, string routingKey,
            CancellationToken cancellationToken = default, string? idempotencyKey = null) where TEvent : IntegrationEvent
        {
            await inner.EnqueueAsync(integrationEvent, routingKey, cancellationToken, idempotencyKey);
            var audit = db.ChangeTracker.Entries<AppointmentStatusAudit>()
                .SingleOrDefault(x => x.Entity.AppointmentId == appointmentId);
            if (audit != null) audit.Entity.Reason = new string('X', 1001);
            await db.SaveChangesAsync(cancellationToken);
        }
    }
}
