using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Common.Exceptions;
using MindBloom.Application.Common.Interfaces;
using MindBloom.Application.Features.Memberships.Interfaces;
using MindBloom.Application.Features.Payments.Interfaces;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;
using MindBloom.Shared.Observability;
using Moq;

namespace MindBloom.UnitTests.Appointments;

public sealed class DashboardStatisticsTests
{
    private static readonly DateTime Now = new(2026, 10, 25, 1, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(PaymentStatus.Paid, 80)]
    [InlineData(PaymentStatus.RefundPending, 80)]
    [InlineData(PaymentStatus.RefundFailed, 80)]
    [InlineData(PaymentStatus.Pending, 0)]
    [InlineData(PaymentStatus.Failed, 0)]
    [InlineData(PaymentStatus.Refunded, 0)]
    public async Task Money_IsTakenFromRetainedPaymentsNotRateOrAppointmentStatus(PaymentStatus status, int expected)
    {
        await using var db = Context();
        var a = Seed(db, AppointmentStatus.Cancelled, Now.AddDays(-1));
        db.Payments.Add(new Payment { Appointment = a, Amount = 80, Status = status, StripePaymentIntentId = "pi_test" });
        await db.SaveChangesAsync();
        var service = Service(db);
        Assert.Equal(expected, (await service.GetClientDashboardAsync(a.Client.UserId)).TotalSpent);
        Assert.Equal(expected, (await service.GetTherapistStatsAsync(a.Therapist.UserId)).TotalEarnings);
        a.Therapist.HourlyRate = 150;
        a.Price = 999;
        await db.SaveChangesAsync();
        Assert.Equal(expected, (await service.GetClientDashboardAsync(a.Client.UserId)).TotalSpent);
    }

    [Theory]
    [InlineData(PaymentStatus.Paid, 250)]
    [InlineData(PaymentStatus.RefundPending, 250)]
    [InlineData(PaymentStatus.RefundFailed, 250)]
    [InlineData(PaymentStatus.Pending, 0)]
    [InlineData(PaymentStatus.Failed, 0)]
    [InlineData(PaymentStatus.Refunded, 0)]
    public async Task MembershipPurchase_IsCountedOnceEvenWithoutSessions(PaymentStatus status, int expected)
    {
        await using var db = Context();
        var a = Seed(db, AppointmentStatus.Completed, Now.AddDays(-1));
        var membership = new ClientMembership { Client = a.Client, Therapist = a.Therapist, TotalSessions = 5, RemainingSessions = 4 };
        db.MembershipPayments.Add(new MembershipPayment { ClientMembership = membership, Amount = 250, Status = status,
            Currency = "usd", StripePaymentIntentId = "pi_member" });
        db.MembershipUsages.Add(new MembershipUsage { Appointment = a, ClientMembership = membership, Status = MembershipUsageStatus.Consumed });
        await db.SaveChangesAsync();
        var service = Service(db);
        Assert.Equal(expected, (await service.GetClientDashboardAsync(a.Client.UserId)).TotalSpent);
        Assert.Equal(0, (await service.GetTherapistStatsAsync(a.Therapist.UserId)).TotalEarnings);
    }

    [Theory]
    [InlineData(AppointmentStatus.Pending, false, true)]
    [InlineData(AppointmentStatus.Accepted, false, true)]
    [InlineData(AppointmentStatus.Completed, true, false)]
    [InlineData(AppointmentStatus.Cancelled, false, false)]
    [InlineData(AppointmentStatus.Rejected, false, false)]
    public async Task DatesAndVisits_RequireCorrectStatus(AppointmentStatus status, bool completed, bool upcoming)
    {
        await using var db = Context();
        var past = Seed(db, status, Now.AddDays(-1));
        var future = new Appointment { Client = past.Client, Therapist = past.Therapist, Status = status,
            StartUtc = Now.AddDays(1), EndUtc = Now.AddDays(1).AddHours(1) };
        db.Add(future);
        await db.SaveChangesAsync();
        var dashboard = await Service(db).GetClientDashboardAsync(past.Client.UserId);
        Assert.Equal(completed ? 1 : 0, dashboard.TotalTherapistsVisited);
        Assert.Equal(completed ? past.EndUtc : (DateTime?)null, dashboard.LastAppointmentDate);
        Assert.Equal(upcoming ? future.StartUtc : (DateTime?)null, dashboard.NextAppointmentDate);
        Assert.Equal(completed ? 2 : 0, (await Service(db).GetTherapistStatsAsync(past.Therapist.UserId)).CompletedAppointments);
        Assert.Equal(0, dashboard.TotalSpent); // Nominal prices and completed history are not proof of payment.
    }

    [Theory]
    [InlineData(3, 29)]
    [InlineData(10, 25)]
    public async Task Dates_UseUtcClockAtDstBoundary(int month, int day)
    {
        var now = new DateTime(2026, month, day, 1, 0, 0, DateTimeKind.Utc);
        await using var db = Context();
        var a = Seed(db, AppointmentStatus.Accepted, now.AddHours(1));
        a.StartUtc = now;
        await db.SaveChangesAsync();
        Assert.Null((await Service(db, now).GetClientDashboardAsync(a.Client.UserId)).NextAppointmentDate);
        a.StartUtc = now.AddTicks(1);
        await db.SaveChangesAsync();
        Assert.Equal(a.StartUtc, (await Service(db, now).GetClientDashboardAsync(a.Client.UserId)).NextAppointmentDate);
    }

    [Fact]
    public async Task EmptyClient_ReturnsZeroMoneyAndNullDates()
    {
        await using var db = Context();
        var client = new Client { User = User() };
        db.Add(client);
        await db.SaveChangesAsync();
        var d = await Service(db).GetClientDashboardAsync(client.UserId);
        Assert.Equal(0, d.TotalSpent);
        Assert.Equal(0, d.TotalTherapistsVisited);
        Assert.Null(d.LastAppointmentDate);
        Assert.Null(d.NextAppointmentDate);
        Assert.Equal("USD", d.Currency);
    }

    [Fact]
    public async Task UnsupportedMembershipCurrency_IsNotSilentlyAddedToUsd()
    {
        await using var db = Context();
        var a = Seed(db, AppointmentStatus.Completed, Now.AddDays(-1));
        db.MembershipPayments.Add(new MembershipPayment { ClientMembership = new ClientMembership { Client = a.Client, Therapist = a.Therapist },
            Amount = 250, Status = PaymentStatus.Paid, Currency = "eur", StripePaymentIntentId = "pi_eur" });
        await db.SaveChangesAsync();
        await Assert.ThrowsAsync<BusinessException>(() => Service(db).GetClientDashboardAsync(a.Client.UserId));
    }

    private static ApplicationUser User() => new() { UserName = Guid.NewGuid().ToString(), FirstName = "Test", LastName = "User" };
    private static Appointment Seed(ApplicationDbContext db, AppointmentStatus status, DateTime end)
    {
        var a = new Appointment { Client = new Client { User = User() }, Therapist = new Therapist { User = User(),
            Biography = "Biography", Specialization = "Test", HourlyRate = 120 }, Status = status,
            StartUtc = end.AddHours(-1), EndUtc = end, AppointmentDateUtc = end.AddHours(-1), Price = 95 };
        db.Add(a);
        return a;
    }
    private static ApplicationDbContext Context() => new(new DbContextOptionsBuilder<ApplicationDbContext>()
        .UseInMemoryDatabase($"dashboard-{Guid.NewGuid():N}").Options);
    private static AppointmentService Service(ApplicationDbContext db, DateTime? now = null) => new(db, Mock.Of<IPaymentService>(),
        Mock.Of<IMembershipService>(), new ApplicationMetrics(), Mock.Of<IIntegrationEventPublisher>(), Mock.Of<IOutboxWriter>(), new Clock(now ?? Now));
    private sealed class Clock(DateTime now) : TimeProvider { public override DateTimeOffset GetUtcNow() => new(now); }
}
