using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Admin.DTOs;
using MindBloom.Application.Features.Admin.Interfaces;
using MindBloom.Application.Features.Appointments.DTOs;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Reviews.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.Messaging.Contracts.Appointments;
using MindBloom.Shared.Constants;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class ManualAppointmentCompletionSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    private static readonly DateTime Now = DateTime.UtcNow;

    [Theory]
    [InlineData(1)]
    [InlineData(5)]
    [InlineData(86400)]
    [InlineData(604800)]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(-604800)]
    public async Task Completion_PreservesRealReservationAndEventsAtUtcBoundary(int seconds)
    {
        var s = await Seed(Now.AddSeconds(seconds));
        var error = await Complete(s);
        Assert.Equal(seconds > 0, error is BusinessException);
        await Verify(s, seconds <= 0 ? AppointmentStatus.Completed : AppointmentStatus.Accepted);
        if (seconds > 0)
        {
            // A failed validation releases the same SQL lock, so retry at EndUtc succeeds.
            Assert.Null(await Complete(s, s.End));
        }
        else
            Assert.IsType<BusinessException>(await Complete(s));
        await Verify(s, AppointmentStatus.Completed);
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task DirectHttp_CompletesOnlyExpiredSessionsAndProtectsReview(bool future)
    {
        var s = await Seed(Now.AddDays(future ? 2 : -2));
        using var therapist = await Login(s.TherapistEmail, s.TherapistUserId);
        using var response = await therapist.PutAsJsonAsync("/api/Appointments/status",
            new UpdateAppointmentStatusDto { AppointmentId = s.Id, Status = AppointmentStatus.Completed });
        Assert.Equal(future ? HttpStatusCode.Conflict : HttpStatusCode.NoContent, response.StatusCode);
        if (future)
        {
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
            var body = await response.Content.ReadAsStringAsync();
            Assert.Contains("scheduled end time", body);
            Assert.Contains("traceId", body);
            Assert.DoesNotContain("SqlException", body);
        }
        await Verify(s, future ? AppointmentStatus.Accepted : AppointmentStatus.Completed);
        using var client = await Login(s.ClientEmail, s.ClientUserId);
        using var review = await client.PostAsJsonAsync("/api/Reviews",
            new CreateReviewDto { AppointmentId = s.Id, Rating = 5, Comment = "Test session review" });
        Assert.Equal(future ? HttpStatusCode.Conflict : HttpStatusCode.Created, review.StatusCode);
    }

    [Theory]
    [InlineData("cancel")]
    [InlineData("admin")]
    [InlineData("automatic-future")]
    [InlineData("automatic-expired")]
    [InlineData("two-completions")]
    [Trait("Category", "ManualCompletionConcurrency")]
    public async Task ConcurrentWriters_KeepStatusAuditAndUsageConsistent(string operation)
    {
        var future = operation is "cancel" or "admin" or "automatic-future";
        var s = await Seed(Now.AddDays(future ? 2 : -2));
        var adminId = operation == "admin"
            ? await factory.SeedActiveUserAsync(RoleConstants.Admin, $"manual-admin-{Guid.NewGuid():N}@test.local", "ManualTest123!") : 0;
        var gate = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        async Task<Exception?> Other()
        {
            await gate.Task;
            using var scope = factory.Services.CreateScope();
            var sp = scope.ServiceProvider;
            var db = sp.GetRequiredService<ApplicationDbContext>();
            try
            {
                if (operation == "cancel")
                    await Service(sp, db).CancelAppointmentAsync(s.ClientUserId, s.Id,
                        new CancelAppointmentDto { Reason = "Test cancellation" });
                else if (operation == "admin")
                    await sp.GetRequiredService<IAdminService>().CancelAppointmentAsync(adminId, s.Id,
                        new AdminCancelAppointmentDto { Reason = "Test administrative cancellation" });
                else if (operation.StartsWith("automatic"))
                    await Service(sp, db).GetMyAppointmentsAsync(s.ClientUserId, 1, 20, null, null, null);
                else return await Complete(s);
                return null;
            }
            catch (BusinessException error) { return error; }
        }
        async Task<Exception?> Manual() { await gate.Task; return await Complete(s); }
        var tasks = new[] { Manual(), Other() };
        gate.SetResult();
        var errors = await Task.WhenAll(tasks);
        if (future) Assert.IsType<BusinessException>(errors[0]);
        if (operation != "two-completions") Assert.Null(errors[1]);
        if (operation == "two-completions") Assert.Single(errors, x => x is null);
        using var verification = factory.Services.CreateScope();
        var verifyDb = verification.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var expected = operation is "cancel" or "admin" ? AppointmentStatus.Cancelled
            : future ? AppointmentStatus.Accepted : AppointmentStatus.Completed;
        Assert.Equal(expected, (await verifyDb.Appointments.FindAsync(s.Id))!.Status);
        var audits = await verifyDb.AppointmentStatusAudits.Where(x => x.AppointmentId == s.Id).ToListAsync();
        Assert.Equal(expected == AppointmentStatus.Accepted ? 0 : 1, audits.Count);
        if (audits.Count > 0) Assert.Equal(AppointmentStatus.Accepted, audits[0].PreviousStatus);
        Assert.Equal(expected == AppointmentStatus.Completed ? 1 : 0,
            await verifyDb.MembershipUsages.CountAsync(x => x.AppointmentId == s.Id && x.Status == MembershipUsageStatus.Consumed));
        Assert.Equal(expected == AppointmentStatus.Completed ? 1 : 0,
            CompletionEvents(s.Id) + await verifyDb.OutboxMessages.CountAsync(x =>
                x.PayloadJson.Contains("\"appointmentId\":" + s.Id + ",") && x.RoutingKey.Contains("completed")));
    }

    [Fact]
    public async Task Completion_ReloadsEndUtcAfterAcquiringLock()
    {
        var s = await Seed(Now.AddDays(-1));
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await db.Appointments.SingleAsync(x => x.Id == s.Id); // Deliberately stale tracked end.
        var actualEnd = Now.AddDays(1);
        using (var writer = factory.Services.CreateScope())
        {
            var writeDb = writer.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            var row = await writeDb.Appointments.FindAsync(s.Id);
            row!.EndUtc = actualEnd;
            await writeDb.SaveChangesAsync();
        }
        await Assert.ThrowsAsync<BusinessException>(() => Service(scope.ServiceProvider, db).UpdateStatusAsync(s.TherapistUserId,
            new UpdateAppointmentStatusDto { AppointmentId = s.Id, Status = AppointmentStatus.Completed }));
        await Verify(s with { End = actualEnd }, AppointmentStatus.Accepted);
    }

    [Fact]
    public async Task RejectedAttempt_LeavesNothingToRollbackAndReleasesLock()
    {
        var s = await Seed(Now.AddDays(2));
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            await using var transaction = await db.Database.BeginTransactionAsync();
            await Assert.ThrowsAsync<BusinessException>(() => Service(scope.ServiceProvider, db).UpdateStatusAsync(s.TherapistUserId,
                new UpdateAppointmentStatusDto { AppointmentId = s.Id, Status = AppointmentStatus.Completed }));
            Assert.False(db.ChangeTracker.HasChanges());
            await transaction.RollbackAsync();
        }
        await Verify(s, AppointmentStatus.Accepted);
        Assert.Null(await Complete(s, s.End));
        await Verify(s, AppointmentStatus.Completed);
    }

    private async Task<Exception?> Complete(Scenario s, DateTime? now = null)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        try
        {
            await Service(scope.ServiceProvider, db, now).UpdateStatusAsync(s.TherapistUserId,
                new UpdateAppointmentStatusDto { AppointmentId = s.Id, Status = AppointmentStatus.Completed });
            return null;
        }
        catch (BusinessException error) { return error; }
    }

    private static AppointmentService Service(IServiceProvider sp, ApplicationDbContext db, DateTime? now = null) => new(
        db, sp.GetRequiredService<IPaymentService>(), sp.GetRequiredService<IMembershipService>(),
        sp.GetRequiredService<ApplicationMetrics>(), sp.GetRequiredService<IIntegrationEventPublisher>(),
        sp.GetRequiredService<IOutboxWriter>(), new FrozenClock(now ?? Now));

    private int CompletionEvents(int id) => factory.Services.GetRequiredService<TestIntegrationEventPublisher>().Events
        .Count(x => x.Event is AppointmentCompletedEvent completed && completed.AppointmentId == id);

    private async Task Verify(Scenario s, AppointmentStatus expected)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var row = (await db.Appointments.FindAsync(s.Id))!;
        Assert.Equal(expected, row.Status);
        Assert.Equal(s.End, row.EndUtc);
        var completed = expected == AppointmentStatus.Completed;
        Assert.Equal(completed ? 1 : 0, await db.AppointmentStatusAudits.CountAsync(x => x.AppointmentId == s.Id));
        Assert.Equal(completed ? 1 : 0, CompletionEvents(s.Id));
        Assert.Empty(await db.OutboxMessages.Where(x => x.PayloadJson.Contains("\"appointmentId\":" + s.Id + ",")).ToListAsync());
        var usage = Assert.Single(await db.MembershipUsages.Where(x => x.AppointmentId == s.Id).ToListAsync());
        Assert.Equal(completed ? MembershipUsageStatus.Consumed : MembershipUsageStatus.Reserved, usage.Status);
        Assert.Equal(completed, usage.ConsumedAtUtc.HasValue);
        Assert.Empty(await db.Notifications.Where(x => x.AppointmentId == s.Id).ToListAsync());
        Assert.Equal(2, (await db.ClientMemberships.FindAsync(s.MembershipId))!.RemainingSessions);
    }

    private async Task<HttpClient> Login(string email, int userId)
    {
        var address = IPAddress.Parse($"2001:db8:13::{userId:x}");
        using var anonymous = new HttpClient(factory.Server.CreateHandler(c => c.Connection.RemoteIpAddress = address))
            { BaseAddress = new Uri("http://localhost") };
        using var login = await anonymous.PostAsJsonAsync("/api/Auth/login-2fa",
            new LoginRequestDto { Email = email, Password = "ManualTest123!" });
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        return factory.CreateBearerClient((await login.Content.ReadFromJsonAsync<Login2FAResponseDto>())!.Auth!.Token);
    }

    private async Task<Scenario> Seed(DateTime end)
    {
        var clientEmail = $"manual-client-{Guid.NewGuid():N}@test.local";
        var therapistEmail = $"manual-therapist-{Guid.NewGuid():N}@test.local";
        var clientUser = await factory.SeedActiveUserAsync(RoleConstants.Client, clientEmail, "ManualTest123!");
        var therapistUser = await factory.SeedActiveUserAsync(RoleConstants.Therapist, therapistEmail, "ManualTest123!");
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var client = new Client { UserId = clientUser };
        var therapist = new Therapist { UserId = therapistUser, Biography = "Biography", Specialization = "Test",
            VerificationStatus = TherapistVerificationStatus.Approved };
        var appointment = new Appointment { Client = client, Therapist = therapist, Status = AppointmentStatus.Accepted,
            StartUtc = end.AddHours(-1), EndUtc = end, AppointmentDateUtc = end.AddHours(-1), Type = AppointmentType.Online };
        var membership = new ClientMembership { Client = client, Therapist = therapist, TotalSessions = 3,
            RemainingSessions = 2, IsActive = true };
        db.AddRange(appointment, membership);
        db.MembershipUsages.Add(new MembershipUsage { Appointment = appointment, ClientMembership = membership,
            Status = MembershipUsageStatus.Reserved, ReservedAtUtc = Now.AddDays(-3) });
        await db.SaveChangesAsync();
        return new(appointment.Id, clientUser, therapistUser, membership.Id, end, clientEmail, therapistEmail);
    }

    private sealed record Scenario(int Id, int ClientUserId, int TherapistUserId, int MembershipId,
        DateTime End, string ClientEmail, string TherapistEmail);
    private sealed class FrozenClock(DateTime utc) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(utc);
    }
}
