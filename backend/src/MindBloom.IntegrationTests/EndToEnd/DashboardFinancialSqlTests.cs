using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Appointments.Interfaces;
using MindBloom.Application.Features.Auth.DTOs;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Application.Features.Therapists.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.IntegrationTests.EndToEnd.Infrastructure;
using MindBloom.Shared.Constants;
using MindBloom.Shared.Observability;

namespace MindBloom.IntegrationTests.EndToEnd;

public sealed class DashboardFinancialSqlTests(MindBloomEndToEndTestFactory factory)
    : IClassFixture<MindBloomEndToEndTestFactory>
{
    [Theory]
    [InlineData(PaymentStatus.Paid, true)]
    [InlineData(PaymentStatus.RefundPending, true)]
    [InlineData(PaymentStatus.RefundFailed, true)]
    [InlineData(PaymentStatus.Pending, false)]
    [InlineData(PaymentStatus.Failed, false)]
    [InlineData(PaymentStatus.Refunded, false)]
    public async Task PaymentStatuses_UseRetainedAmountsAcrossAllDashboards(PaymentStatus status, bool retained)
    {
        var s = await Seed();
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<ApplicationDbContext>();
        db.Payments.Add(Payment(s, 80.25m, status, AppointmentStatus.Cancelled));
        await db.SaveChangesAsync();
        var service = sp.GetRequiredService<IAppointmentService>();
        var expected = retained ? 80.25m : 0;
        Assert.Equal(expected, (await service.GetClientDashboardAsync(s.ClientUser)).TotalSpent);
        Assert.Equal(expected, (await service.GetTherapistStatsAsync(s.TherapistUser)).TotalEarnings);
        Assert.Equal(expected, (await sp.GetRequiredService<ITherapistService>().GetDashboardAsync(s.TherapistUser)).TotalEarnings);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(3)]
    public async Task MembershipPurchase_IsNotMultipliedByUsageCount(int sessions)
    {
        var s = await Seed();
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<ApplicationDbContext>();
        var member = Membership(s, 250, PaymentStatus.Paid);
        db.Add(member);
        for (var i = 0; i < sessions; i++)
            db.MembershipUsages.Add(new MembershipUsage { ClientMembership = member.ClientMembership,
                Appointment = Appointment(s, AppointmentStatus.Completed, DateTime.UtcNow.AddDays(-i - 1)), Status = MembershipUsageStatus.Consumed });
        await db.SaveChangesAsync();
        Assert.Equal(250m, (await sp.GetRequiredService<IAppointmentService>().GetClientDashboardAsync(s.ClientUser)).TotalSpent);
        Assert.Equal(0m, (await sp.GetRequiredService<IAppointmentService>().GetTherapistStatsAsync(s.TherapistUser)).TotalEarnings);
        Assert.Equal(0m, (await sp.GetRequiredService<ITherapistService>().GetDashboardAsync(s.TherapistUser)).TotalEarnings);
    }

    [Fact]
    public async Task KnownAmounts_HistoricalRateAndUserIsolationRemainCorrect()
    {
        var s = await Seed();
        var other = await Seed();
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<ApplicationDbContext>();
        db.AddRange(Payment(s, 80, PaymentStatus.Paid), Payment(s, 95, PaymentStatus.Paid),
            Payment(s, 500, PaymentStatus.Pending), Payment(s, 600, PaymentStatus.Failed), Payment(s, 700, PaymentStatus.Refunded),
            Payment(other, 999, PaymentStatus.Paid));
        var member = Membership(s, 250, PaymentStatus.Paid);
        db.Add(member);
        for (var i = 0; i < 2; i++)
            db.MembershipUsages.Add(new MembershipUsage { ClientMembership = member.ClientMembership,
                Appointment = Appointment(s, AppointmentStatus.Completed, DateTime.UtcNow.AddDays(-i - 1)), Status = MembershipUsageStatus.Consumed });
        // Historical completed appointment has a nominal price but no payment evidence.
        db.Add(Appointment(s, AppointmentStatus.Completed, DateTime.UtcNow.AddDays(-5)));
        await db.SaveChangesAsync();
        var service = sp.GetRequiredService<IAppointmentService>();
        Assert.Equal(425m, (await service.GetClientDashboardAsync(s.ClientUser)).TotalSpent);
        Assert.Equal(175m, (await service.GetTherapistStatsAsync(s.TherapistUser)).TotalEarnings);
        Assert.Equal(175m, (await sp.GetRequiredService<ITherapistService>().GetDashboardAsync(s.TherapistUser)).TotalEarnings);
        Assert.Equal(999m, (await service.GetClientDashboardAsync(other.ClientUser)).TotalSpent);
        (await db.Therapists.FindAsync(s.Therapist))!.HourlyRate = 150;
        await db.SaveChangesAsync();
        Assert.Equal(425m, (await service.GetClientDashboardAsync(s.ClientUser)).TotalSpent);
        Assert.Equal(175m, (await service.GetTherapistStatsAsync(s.TherapistUser)).TotalEarnings);
        Assert.Equal(new[] { 80m, 95m }, await db.Payments.Where(x => x.Appointment.ClientId == s.Client && x.Status == PaymentStatus.Paid)
            .OrderBy(x => x.Amount).Select(x => x.Amount).ToArrayAsync());
    }

    [Fact]
    public async Task PaymentAttempts_UpdateOneRecordAndConfirmedRefundRemovesIt()
    {
        var s = await Seed();
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var service = scope.ServiceProvider.GetRequiredService<IAppointmentService>();
        var payment = Payment(s, 80, PaymentStatus.Failed);
        db.Add(payment);
        await db.SaveChangesAsync();
        foreach (var status in new[] { PaymentStatus.Failed, PaymentStatus.Pending, PaymentStatus.Paid, PaymentStatus.RefundPending,
                     PaymentStatus.RefundFailed, PaymentStatus.Refunded })
        {
            payment.Status = status;
            await db.SaveChangesAsync();
            var expected = status is PaymentStatus.Paid or PaymentStatus.RefundPending or PaymentStatus.RefundFailed ? 80m : 0m;
            Assert.Equal(expected, (await service.GetClientDashboardAsync(s.ClientUser)).TotalSpent);
            Assert.Equal(1, await db.Payments.CountAsync(x => x.AppointmentId == payment.AppointmentId));
        }
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task SqlSchema_RejectsDuplicatePaymentsForOnePurchase(bool membership)
    {
        var s = await Seed();
        int id;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            if (membership)
            {
                var value = Membership(s, 80, PaymentStatus.Paid);
                db.Add(value);
                await db.SaveChangesAsync();
                id = value.ClientMembershipId;
                db.ChangeTracker.Clear(); // Exercise the SQL unique constraint, not tracked one-to-one navigation fixup.
                db.Add(new MembershipPayment { ClientMembershipId = id, Amount = 100, Currency = "usd", Status = PaymentStatus.Paid,
                    StripePaymentIntentId = Guid.NewGuid().ToString() });
            }
            else
            {
                var value = Payment(s, 80, PaymentStatus.Paid);
                db.Add(value);
                await db.SaveChangesAsync();
                id = value.AppointmentId;
                db.ChangeTracker.Clear();
                db.Add(new Payment { AppointmentId = id, Amount = 100, Status = PaymentStatus.Paid, StripePaymentIntentId = Guid.NewGuid().ToString() });
            }
            await Assert.ThrowsAsync<DbUpdateException>(() => db.SaveChangesAsync());
        }
        using var verify = factory.Services.CreateScope();
        Assert.Equal(80m, (await verify.ServiceProvider.GetRequiredService<IAppointmentService>().GetClientDashboardAsync(s.ClientUser)).TotalSpent);
    }

    [Fact]
    public async Task DecimalTotalsAndPaidPeriods_AreConsistentAcrossTherapistEndpoints()
    {
        var s = await Seed();
        var now = DateTime.UtcNow;
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<ApplicationDbContext>();
        db.AddRange(Payment(s, 0.10m, PaymentStatus.Paid), Payment(s, 0.20m, PaymentStatus.RefundPending));
        var old = Payment(s, 12.34m, PaymentStatus.Paid);
        old.PaidAtUtc = now.AddYears(-1);
        db.Add(old);
        await db.SaveChangesAsync();
        var stats = await sp.GetRequiredService<IAppointmentService>().GetTherapistStatsAsync(s.TherapistUser);
        var dashboard = await sp.GetRequiredService<ITherapistService>().GetDashboardAsync(s.TherapistUser);
        Assert.Equal(12.64m, stats.TotalEarnings);
        Assert.Equal(stats.TotalEarnings, dashboard.TotalEarnings);
        Assert.Equal(0.30m, dashboard.MonthlyEarnings);
        Assert.Equal(0.30m, dashboard.WeeklyEarnings);
        Assert.Equal("USD", dashboard.Currency);
    }

    [Fact]
    public async Task FinancialHistory_SurvivesAppointmentDeletionButDeletedPaymentIsExcluded()
    {
        var s = await Seed();
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<ApplicationDbContext>();
        var paid = Payment(s, 80, PaymentStatus.Paid);
        paid.Appointment.IsDeleted = true;
        var deleted = Payment(s, 100, PaymentStatus.Paid);
        deleted.IsDeleted = true;
        db.AddRange(paid, deleted);
        await db.SaveChangesAsync();
        Assert.Equal(80m, (await sp.GetRequiredService<IAppointmentService>().GetClientDashboardAsync(s.ClientUser)).TotalSpent);
        var dashboard = await sp.GetRequiredService<ITherapistService>().GetDashboardAsync(s.TherapistUser);
        Assert.Equal(80m, dashboard.TotalEarnings);
        Assert.Equal(80m, dashboard.MonthlyEarnings);
    }

    [Theory]
    [InlineData(3, 29)]
    [InlineData(10, 25)]
    public async Task StatusDatesAndCounts_UseUtcWithoutMutatingPastAccepted(int month, int day)
    {
        var s = await Seed();
        var now = new DateTime(2026, month, day, 1, 0, 0, DateTimeKind.Utc);
        using var scope = factory.Services.CreateScope();
        var sp = scope.ServiceProvider;
        var db = sp.GetRequiredService<ApplicationDbContext>();
        var completed = Appointment(s, AppointmentStatus.Completed, now.AddDays(-4));
        db.AddRange(completed, Appointment(s, AppointmentStatus.Completed, now.AddDays(-3)),
            Appointment(s, AppointmentStatus.Accepted, now.AddDays(-1)), Appointment(s, AppointmentStatus.Pending, now.AddHours(-2)),
            Appointment(s, AppointmentStatus.Cancelled, now.AddHours(-1)), Appointment(s, AppointmentStatus.Rejected, now.AddMinutes(-30)),
            Appointment(s, AppointmentStatus.Cancelled, now.AddHours(2)), Appointment(s, AppointmentStatus.Rejected, now.AddHours(3)));
        var next = Appointment(s, AppointmentStatus.Accepted, now.AddHours(4));
        db.Add(next);
        var tied = Appointment(s, AppointmentStatus.Pending, next.EndUtc);
        db.Add(tied);
        await db.SaveChangesAsync();
        var service = new AppointmentService(db, sp.GetRequiredService<IPaymentService>(), sp.GetRequiredService<IMembershipService>(),
            sp.GetRequiredService<ApplicationMetrics>(), sp.GetRequiredService<IIntegrationEventPublisher>(), sp.GetRequiredService<IOutboxWriter>(), new Clock(now));
        var result = await service.GetClientDashboardAsync(s.ClientUser);
        Assert.Equal(1, result.TotalTherapistsVisited);
        Assert.Equal(now.AddDays(-3), result.LastAppointmentDate);
        Assert.Equal(next.StartUtc, result.NextAppointmentDate);
        Assert.Equal(DateTimeKind.Utc, result.NextAppointmentDate!.Value.Kind);
        Assert.Equal(DateTimeKind.Utc, result.LastAppointmentDate!.Value.Kind);
        Assert.Equal(2, (await service.GetTherapistStatsAsync(s.TherapistUser)).CompletedAppointments);
        Assert.Equal(1, await db.Appointments.CountAsync(x => x.ClientId == s.Client && x.Status == AppointmentStatus.Accepted && x.EndUtc < now));
    }

    [Fact]
    public async Task HttpDashboards_AreIsolatedAuthorizedAndSerializeNullAndUtcDates()
    {
        var s = await Seed();
        using var client = await Login(s.ClientEmail, s.ClientUser);
        using var therapist = await Login(s.TherapistEmail, s.TherapistUser);
        using var anonymous = factory.CreateClient();
        using var empty = await client.GetAsync("/api/Appointments/client-dashboard");
        Assert.Equal(HttpStatusCode.OK, empty.StatusCode);
        var json = JsonDocument.Parse(await empty.Content.ReadAsStringAsync());
        Assert.Equal(JsonValueKind.Null, json.RootElement.GetProperty("lastAppointmentDate").ValueKind);
        Assert.Equal(JsonValueKind.Null, json.RootElement.GetProperty("nextAppointmentDate").ValueKind);
        Assert.Equal("USD", json.RootElement.GetProperty("currency").GetString());
        Assert.Equal(HttpStatusCode.Forbidden, (await client.GetAsync("/api/Appointments/therapist/stats")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await therapist.GetAsync("/api/Appointments/client-dashboard")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await anonymous.GetAsync("/api/Appointments/client-dashboard")).StatusCode);
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
            db.AddRange(Payment(s, 80, PaymentStatus.Paid), Appointment(s, AppointmentStatus.Accepted, DateTime.UtcNow.AddDays(2)));
            await db.SaveChangesAsync();
        }
        using var populated = await client.GetAsync("/api/Appointments/client-dashboard?clientUserId=999999");
        json = JsonDocument.Parse(await populated.Content.ReadAsStringAsync());
        Assert.Equal(80m, json.RootElement.GetProperty("totalSpent").GetDecimal());
        Assert.EndsWith("Z", json.RootElement.GetProperty("nextAppointmentDate").GetString());
        using var stats = await therapist.GetAsync("/api/Appointments/therapist/stats?therapistUserId=999999");
        using var dashboard = await therapist.GetAsync("/api/Therapists/dashboard");
        Assert.Equal(HttpStatusCode.OK, stats.StatusCode);
        Assert.Equal(HttpStatusCode.OK, dashboard.StatusCode);
        Assert.Equal(80m, JsonDocument.Parse(await stats.Content.ReadAsStringAsync()).RootElement.GetProperty("totalEarnings").GetDecimal());
        Assert.Equal(80m, JsonDocument.Parse(await dashboard.Content.ReadAsStringAsync()).RootElement.GetProperty("totalEarnings").GetDecimal());
    }

    private async Task<Scenario> Seed()
    {
        var clientEmail = $"dashboard-client-{Guid.NewGuid():N}@test.local";
        var therapistEmail = $"dashboard-therapist-{Guid.NewGuid():N}@test.local";
        var clientUser = await factory.SeedActiveUserAsync(RoleConstants.Client, clientEmail, "DashboardTest123!");
        var therapistUser = await factory.SeedActiveUserAsync(RoleConstants.Therapist, therapistEmail, "DashboardTest123!");
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var client = new Client { UserId = clientUser };
        var therapist = new Therapist { UserId = therapistUser, Biography = "Biography", Specialization = "Test", HourlyRate = 120 };
        db.AddRange(client, therapist);
        await db.SaveChangesAsync();
        return new(client.Id, clientUser, therapist.Id, therapistUser, clientEmail, therapistEmail);
    }
    private static Appointment Appointment(Scenario s, AppointmentStatus status, DateTime end) => new()
        { ClientId = s.Client, TherapistId = s.Therapist, StartUtc = end.AddHours(-1), EndUtc = end, AppointmentDateUtc = end.AddHours(-1), Status = status, Price = 120 };
    private static Payment Payment(Scenario s, decimal amount, PaymentStatus status, AppointmentStatus appointmentStatus = AppointmentStatus.Completed) => new()
        { Appointment = Appointment(s, appointmentStatus, DateTime.UtcNow.AddDays(-2)), Amount = amount, Status = status,
            StripePaymentIntentId = $"pi_{Guid.NewGuid():N}", PaidAtUtc = DateTime.UtcNow };
    private static MembershipPayment Membership(Scenario s, decimal amount, PaymentStatus status) => new()
        { ClientMembership = new ClientMembership { ClientId = s.Client, TherapistId = s.Therapist, TotalSessions = 5, RemainingSessions = 5 },
            Amount = amount, Status = status, Currency = "usd", StripePaymentIntentId = $"pi_{Guid.NewGuid():N}", PaidAtUtc = DateTime.UtcNow };
    private async Task<HttpClient> Login(string email, int id)
    {
        using var anonymous = new HttpClient(factory.Server.CreateHandler(c => c.Connection.RemoteIpAddress = IPAddress.Parse($"2001:db8:15::{id:x}")))
            { BaseAddress = new Uri("http://localhost") };
        using var response = await anonymous.PostAsJsonAsync("/api/Auth/login-2fa", new LoginRequestDto { Email = email, Password = "DashboardTest123!" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return factory.CreateBearerClient((await response.Content.ReadFromJsonAsync<Login2FAResponseDto>())!.Auth!.Token);
    }
    private sealed record Scenario(int Client, int ClientUser, int Therapist, int TherapistUser, string ClientEmail, string TherapistEmail);
    private sealed class Clock(DateTime now) : TimeProvider { public override DateTimeOffset GetUtcNow() => new(now); }
}
