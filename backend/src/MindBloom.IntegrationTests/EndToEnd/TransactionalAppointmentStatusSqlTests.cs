using System.Data.Common;
using System.Net;
using System.Net.Http.Json;
using System.Reflection;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using MindBloom.API.Messaging.Outbox;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Messaging.Outbox;
using MindBloom.Infrastructure.Payments;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Messaging.Contracts.Common;
using MindBloom.NotificationsWorker.Handlers.Appointments;
using MindBloom.NotificationsWorker.Services;
using MindBloom.Shared.Constants;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class TransactionalAppointmentStatusSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Theory]
    [InlineData(null, false)]
    [InlineData("", false)]
    [InlineData("   ", false)]
    [InlineData("abcd", false)]
    [InlineData("abcde", true)]
    [InlineData("  abcde  ", true)]
    [InlineData("Nisam u mogućnosti održati termin.", true)]
    public async Task RejectionHttp_ValidatesAndPersistsReasonAtomically(string? reason, bool valid)
    {
        var s = await Seed();
        using var http = await Login(s.Email, s.TherapistUser);
        using var response = await http.PutAsJsonAsync("/api/Appointments/status", new UpdateAppointmentStatusDto
            { AppointmentId = s.Id, Status = AppointmentStatus.Rejected, Reason = reason });
        Assert.Equal(valid ? HttpStatusCode.NoContent : HttpStatusCode.BadRequest, response.StatusCode);
        if (!valid)
        {
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
            var body = await response.Content.ReadAsStringAsync();
            Assert.Contains("traceId", body);
            Assert.Contains("detail", body);
        }
        await Verify(s, valid ? AppointmentStatus.Rejected : AppointmentStatus.Pending, valid ? reason!.Trim() : null);
    }

    [Theory]
    [InlineData(500, true)]
    [InlineData(501, false)]
    public async Task DirectService_CannotBypassMaximumLength(int length, bool valid)
    {
        var s = await Seed();
        var reason = new string('ž', length);
        if (valid) await Change(s, AppointmentStatus.Rejected, reason);
        else await Assert.ThrowsAsync<BadRequestException>(() => Change(s, AppointmentStatus.Rejected, reason));
        await Verify(s, valid ? AppointmentStatus.Rejected : AppointmentStatus.Pending, valid ? reason : null);
    }

    [Theory]
    [InlineData("membership", false)]
    [InlineData("status", false)]
    [InlineData("audit", false)]
    [InlineData("outbox", false)]
    [InlineData("commit", false)]
    [InlineData("membership", true)]
    [InlineData("status", true)]
    [InlineData("audit", true)]
    [InlineData("outbox", true)]
    [InlineData("commit", true)]
    public async Task Failure_RollsBackRealSqlWritesAndAllowsRetry(string fault, bool completion)
    {
        var s = await Seed(completion);
        var target = completion ? AppointmentStatus.Completed : AppointmentStatus.Rejected;
        var error = await Record.ExceptionAsync(() => Change(s, target, "A scheduling conflict", fault));
        Assert.NotNull(error);
        if (fault == "audit") Assert.IsType<DbUpdateException>(error);
        else Assert.IsType<InvalidOperationException>(error);
        await Verify(s, completion ? AppointmentStatus.Accepted : AppointmentStatus.Pending);
        await Change(s, target, "A scheduling conflict");
        await Verify(s, target, completion ? null : "A scheduling conflict");
    }

    [Theory]
    [InlineData("reject")]
    [InlineData("accept")]
    [InlineData("cancel")]
    [InlineData("automatic")]
    [Trait("Category", "TransactionalStatusConcurrency")]
    public async Task ConcurrentRejection_ProducesOnlyLegalTransitionsAndOneResolution(string other)
    {
        var s = await Seed(expired: other == "automatic");
        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        async Task<Exception?> Attempt(Func<Task> action)
        {
            await gate.Task;
            try { await action(); return null; } catch (BusinessException e) { return e; }
        }
        var first = Attempt(() => Change(s, AppointmentStatus.Rejected, "The therapist cannot attend."));
        var second = Attempt(async () =>
        {
            using var scope = factory.Services.CreateScope();
            var service = scope.ServiceProvider.GetRequiredService<IAppointmentService>();
            if (other == "cancel")
                await service.CancelAppointmentAsync(s.ClientUser, s.Id, new CancelAppointmentDto { Reason = "Client cannot attend" });
            else if (other == "automatic")
                await service.GetMyAppointmentsAsync(s.ClientUser, 1, 20, null, null, null);
            else await service.UpdateStatusAsync(s.TherapistUser, new()
                { AppointmentId = s.Id, Status = other == "accept" ? AppointmentStatus.Accepted : AppointmentStatus.Rejected,
                  Reason = "Another rejection reason" });
        });
        gate.SetResult();
        var errors = await Task.WhenAll(first, second);
        Assert.Contains(errors, x => x == null);
        using var check = factory.Services.CreateScope();
        var db = check.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var row = (await db.Appointments.FindAsync(s.Id))!;
        Assert.Contains(row.Status, new[] { AppointmentStatus.Accepted, AppointmentStatus.Rejected, AppointmentStatus.Cancelled });
        var audits = await db.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).ToListAsync();
        var audit = Assert.Single(audits);
        Assert.Equal(AppointmentStatus.Pending, audit.PreviousStatus);
        Assert.Equal(row.Status, audit.NewStatus);
        if (row.Status == AppointmentStatus.Rejected) Assert.False(string.IsNullOrWhiteSpace(audit.Reason));
        var usage = await db.MembershipUsages.SingleAsync(x => x.AppointmentId == s.Id);
        Assert.NotEqual(MembershipUsageStatus.Consumed, usage.Status);
        Assert.InRange((await db.ClientMemberships.FindAsync(s.Membership))!.RemainingSessions, 2, 3);
        Assert.Single(await Events(db, s.Id));
    }

    [Fact]
    public async Task CommittedRejection_OutboxProcessorPublishesOnceAndHandlerShowsActualReason()
    {
        var s = await Seed();
        const string reason = "Nisam u mogućnosti održati termin.";
        await Change(s, AppointmentStatus.Rejected, reason);
        var publisher = factory.Services.GetRequiredService<TestIntegrationEventPublisher>();
        Assert.DoesNotContain(publisher.Events, x => x.Event is AppointmentRejectedEvent e && e.AppointmentId == s.Id);
        using var optionsScope = factory.Services.CreateScope();
        await using var deliveryServices = new ServiceCollection()
            .AddSingleton(optionsScope.ServiceProvider.GetRequiredService<DbContextOptions<ApplicationDbContext>>())
            .AddScoped<ApplicationDbContext>()
            .AddSingleton<IIntegrationEventPublisher>(new FailOncePublisher(publisher, s.Id))
            .BuildServiceProvider();
        using var processor = new OutboxMessageProcessor(deliveryServices.GetRequiredService<IServiceScopeFactory>(),
            NullLogger<OutboxMessageProcessor>.Instance);
        var method = typeof(OutboxMessageProcessor).GetMethod("ProcessBatchAsync", BindingFlags.Instance | BindingFlags.NonPublic)!;
        await (Task<bool>)method.Invoke(processor, new object[] { CancellationToken.None })!;
        using (var retryScope = factory.Services.CreateScope())
        {
            var retryDb = retryScope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var pending = Assert.Single(await Events(retryDb, s.Id));
            Assert.Equal(OutboxMessageStatus.RetryPending, pending.Status);
            Assert.Equal(1, pending.AttemptCount);
            pending.NextAttemptAtUtc = DateTime.UtcNow.AddSeconds(-1);
            await retryDb.SaveChangesAsync();
        }
        for (var attempt = 0; attempt < 4; attempt++)
            await (Task<bool>)method.Invoke(processor, new object[] { CancellationToken.None })!;
        var rejected = Assert.Single(publisher.Events.Select(x => x.Event).OfType<AppointmentRejectedEvent>(), x => x.AppointmentId == s.Id);
        Assert.Equal(reason, rejected.Reason);
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var notifications = new WorkerNotificationService(db, new NoEmail(), new NoPush(), new ApplicationMetrics(),
            NullLogger<WorkerNotificationService>.Instance);
        var inbox = new ProcessedMessageService(db, NullLogger<ProcessedMessageService>.Instance);
        for (var delivery = 0; delivery < 2; delivery++)
        {
            if (await inbox.IsProcessedAsync(rejected.EventId, "IntegrationEventConsumer")) continue;
            await new AppointmentRejectedEventHandler(notifications).HandleAsync(rejected, CancellationToken.None);
            await inbox.MarkAsProcessedAsync(rejected.EventId, "IntegrationEventConsumer", nameof(AppointmentRejectedEvent), rejected.CorrelationId);
        }
        Assert.Contains(reason, (await db.Notifications.SingleAsync(x => x.AppointmentId == s.Id)).Message);
        Assert.Equal(OutboxMessageStatus.Processed, Assert.Single(await Events(db, s.Id)).Status);
        var clientEmail = (await db.Users.FindAsync(s.ClientUser))!.Email!;
        using var client = await Login(clientEmail, s.ClientUser);
        using var response = await client.GetAsync("/api/Notifications?pageNumber=1&pageSize=20");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        Assert.Contains(json.RootElement.GetProperty("items").EnumerateArray(),
            item => item.GetProperty("message").GetString()!.Contains(reason));
    }

    [Fact]
    public async Task RejectionWithoutMembership_AndAuthorizationRemainCorrect()
    {
        var s = await Seed();
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.MembershipUsages.Remove(await db.MembershipUsages.SingleAsync(x => x.AppointmentId == s.Id));
            await db.SaveChangesAsync();
        }
        await Assert.ThrowsAsync<NotFoundException>(() => Change(s with { TherapistUser = s.ClientUser }, AppointmentStatus.Rejected, "Valid reason"));
        await Change(s, AppointmentStatus.Rejected, "Valid reason");
        using var verify = factory.Services.CreateScope();
        Assert.Equal(AppointmentStatus.Rejected, (await verify.ServiceProvider.GetRequiredService<ApplicationDbContext>().Appointments.FindAsync(s.Id))!.Status);
    }

    private async Task Change(Scenario s, AppointmentStatus target, string? reason, string? fault = null)
    {
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var builder = new DbContextOptionsBuilder<ApplicationDbContext>(sp.GetRequiredService<DbContextOptions<ApplicationDbContext>>());
        if (fault != null) builder.AddInterceptors(new SaveFault(fault), new CommitFault(fault));
        await using var db = new ApplicationDbContext(builder.Options);
        var writer = new OutboxWriter(db, sp.GetRequiredService<ICorrelationIdAccessor>());
        var publisher = sp.GetRequiredService<IIntegrationEventPublisher>();
        var membership = new MembershipService(db, sp.GetRequiredService<StripeClientProvider>(),
            sp.GetRequiredService<StripeVerificationService>(), publisher, writer);
        var service = new AppointmentService(db, sp.GetRequiredService<IPaymentService>(), membership,
            sp.GetRequiredService<ApplicationMetrics>(), publisher, fault == "outbox" ? new FaultingOutbox(db, writer) : writer);
        await service.UpdateStatusAsync(s.TherapistUser, new() { AppointmentId = s.Id, Status = target, Reason = reason });
    }

    private async Task Verify(Scenario s, AppointmentStatus expected, string? reason = null)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        Assert.Equal(expected, (await db.Appointments.FindAsync(s.Id))!.Status);
        var changed = expected is AppointmentStatus.Rejected or AppointmentStatus.Completed;
        var audits = await db.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).ToListAsync();
        Assert.Equal(changed ? 1 : 0, audits.Count);
        if (changed)
        {
            Assert.Equal(s.TherapistUser, audits[0].ChangedByUserId);
            if (reason != null) Assert.Equal(reason, audits[0].Reason);
        }
        var events = await Events(db, s.Id);
        Assert.Equal(changed ? 1 : 0, events.Count);
        if (reason != null) Assert.Equal(reason, JsonDocument.Parse(events[0].PayloadJson).RootElement.GetProperty("reason").GetString());
        var usage = await db.MembershipUsages.SingleAsync(x => x.AppointmentId == s.Id);
        Assert.Equal(expected == AppointmentStatus.Rejected ? MembershipUsageStatus.Restored
            : expected == AppointmentStatus.Completed ? MembershipUsageStatus.Consumed : MembershipUsageStatus.Reserved, usage.Status);
        Assert.Equal(expected == AppointmentStatus.Rejected ? 3 : 2, (await db.ClientMemberships.FindAsync(s.Membership))!.RemainingSessions);
        Assert.Empty(await db.Notifications.Where(x => x.AppointmentId == s.Id).ToListAsync());
        Assert.DoesNotContain(factory.Services.GetRequiredService<TestIntegrationEventPublisher>().Events,
            x => x.Event is AppointmentRejectedEvent e && e.AppointmentId == s.Id);
    }

    private async Task<Scenario> Seed(bool completion = false, bool expired = false)
    {
        var email = $"transactional-therapist-{Guid.NewGuid():N}@test.local";
        var therapistUser = await factory.SeedActiveUserAsync(RoleConstants.Therapist, email, "TransactionalTest123!");
        var clientUser = await factory.SeedActiveUserAsync(RoleConstants.Client, $"transactional-client-{Guid.NewGuid():N}@test.local", "TransactionalTest123!");
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var client = new Client { UserId = clientUser };
        var therapist = new Therapist { UserId = therapistUser, Biography = "Biography", Specialization = "Test" };
        var end = DateTime.UtcNow.AddDays(completion || expired ? -1 : 2);
        var row = new Appointment { Client = client, Therapist = therapist, StartUtc = end.AddHours(-1), EndUtc = end,
            AppointmentDateUtc = end.AddHours(-1), Status = completion ? AppointmentStatus.Accepted : AppointmentStatus.Pending };
        var membership = new ClientMembership { Client = client, Therapist = therapist, TotalSessions = 3, RemainingSessions = 2, IsActive = true };
        db.AddRange(row, membership);
        db.MembershipUsages.Add(new MembershipUsage { Appointment = row, ClientMembership = membership,
            Status = MembershipUsageStatus.Reserved, ReservedAtUtc = DateTime.UtcNow.AddDays(-3) });
        await db.SaveChangesAsync();
        return new(row.Id, therapistUser, clientUser, membership.Id, email);
    }

    private async Task<HttpClient> Login(string email, int id)
    {
        using var anonymous = new HttpClient(factory.Server.CreateHandler(c => c.Connection.RemoteIpAddress = IPAddress.Parse($"2001:db8:14::{id:x}")))
            { BaseAddress = new Uri("http://localhost") };
        using var response = await anonymous.PostAsJsonAsync("/api/Auth/login-2fa", new LoginRequestDto { Email = email, Password = "TransactionalTest123!" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return factory.CreateBearerClient((await response.Content.ReadFromJsonAsync<Login2FAResponseDto>())!.Auth!.Token);
    }

    private static Task<List<OutboxMessage>> Events(ApplicationDbContext db, int id) => db.OutboxMessages
        .Where(x => x.PayloadJson.Contains("\"appointmentId\":" + id + ",")).ToListAsync();
    private sealed record Scenario(int Id, int TherapistUser, int ClientUser, int Membership, string Email);
    private sealed class SaveFault(string fault) : SaveChangesInterceptor
    {
        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(DbContextEventData data, InterceptionResult<int> result, CancellationToken ct = default)
        {
            var audit = data.Context!.ChangeTracker.Entries<AppointmentStatusAudit>().FirstOrDefault();
            if (audit != null && fault == "status") throw new InvalidOperationException("Injected status save failure");
            if (audit != null && fault == "audit") audit.Entity.Reason = new string('x', 1001);
            return base.SavingChangesAsync(data, result, ct);
        }
        public override ValueTask<int> SavedChangesAsync(SaveChangesCompletedEventData data, int result, CancellationToken ct = default)
        {
            if (fault == "membership") throw new InvalidOperationException("Injected failure after membership save");
            return base.SavedChangesAsync(data, result, ct);
        }
    }
    private sealed class CommitFault(string fault) : DbTransactionInterceptor
    {
        public override ValueTask<InterceptionResult> TransactionCommittingAsync(DbTransaction transaction, TransactionEventData data,
            InterceptionResult result, CancellationToken ct = default) => fault == "commit"
                ? throw new InvalidOperationException("Injected failure before commit") : base.TransactionCommittingAsync(transaction, data, result, ct);
    }
    private sealed class FaultingOutbox(ApplicationDbContext db, IOutboxWriter inner) : IOutboxWriter
    {
        public async Task EnqueueAsync<T>(T value, string key, CancellationToken ct = default, string? idempotencyKey = null) where T : IntegrationEvent
        {
            await inner.EnqueueAsync(value, key, ct, idempotencyKey);
            await db.SaveChangesAsync(ct);
            throw new InvalidOperationException("Injected failure after outbox save");
        }
    }
    private sealed class NoEmail : IEmailService { public Task SendAsync(string to, string subject, string body) => Task.CompletedTask; }
    private sealed class FailOncePublisher(IIntegrationEventPublisher inner, int appointmentId) : IIntegrationEventPublisher
    {
        private bool _failed;
        public Task PublishAsync(IntegrationEvent value, string key, CancellationToken ct = default)
        {
            if (!_failed && value is AppointmentRejectedEvent rejected && rejected.AppointmentId == appointmentId)
            {
                _failed = true;
                throw new InvalidOperationException("Injected delivery failure");
            }
            return inner.PublishAsync(value, key, ct);
        }
        public Task PublishAsync<T>(T value, string key, CancellationToken ct = default) where T : IntegrationEvent => PublishAsync((IntegrationEvent)value, key, ct);
    }
    private sealed class NoPush : IPushNotificationService
    {
        public Task SendToUserAsync(int id, string title, string message, IReadOnlyDictionary<string, string>? data = null, CancellationToken ct = default) => Task.CompletedTask;
    }
}
