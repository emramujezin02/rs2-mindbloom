using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using MindBloom.Application.Features.AdminReports.DTOs;
using MindBloom.Domain.Entities;
using MindBloom.Domain.Enums;
using MindBloom.Infrastructure.Persistence.Context;
using MindBloom.Infrastructure.Services;

namespace MindBloom.UnitTests.Reports;

// No application host, SQL, Stripe or network. Only GUID-scoped EF InMemory data.
public sealed class AdminDashboardCurrencyTests
{
    private static readonly DateTime January = new(2026, 1, 10, 12, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(true, false, 50)]
    [InlineData(false, true, 20)]
    [InlineData(true, true, 70)]
    public async Task Usd_sources_are_summed_once(bool direct, bool membership, decimal expected)
    {
        await using var s = new Scenario();
        if (direct) s.Direct(50m, January);
        if (membership) s.Membership(20m, "usd", January);
        var result = await s.ReportAsync();
        var usd = Assert.Single(result.RevenueByCurrency);
        Assert.Equal("USD", usd.Currency);
        Assert.Equal(expected, usd.TotalRevenue);
        Assert.Equal(expected, usd.PeriodRevenue);
        Assert.Equal(expected, Assert.Single(usd.RevenueByMonth).Revenue);
        Assert.Equal(expected, result.TotalRevenue);
        Assert.False(s.Db.ChangeTracker.HasChanges());
    }

    [Theory]
    [InlineData("USD")]
    [InlineData("usd")]
    [InlineData(" UsD ")]
    public async Task Membership_currency_is_trimmed_and_case_normalized(string currency)
    {
        await using var s = new Scenario();
        s.Direct(50m, January);
        s.Membership(20m, currency, January);
        Assert.Equal(70m, Assert.Single((await s.ReportAsync()).RevenueByCurrency).TotalRevenue);
        Assert.Equal(currency, (await s.Db.MembershipPayments.SingleAsync()).Currency);
    }

    [Fact]
    public async Task Mixed_and_unfamiliar_valid_currencies_stay_separate()
    {
        await using var s = new Scenario();
        s.Direct(50m, January);
        s.Membership(20m, " Bam ", January);
        s.Membership(30m, "XYZ", January);
        s.Membership(40m, "EUR", January);
        var result = await s.ReportAsync();
        Assert.Equal(4, result.RevenueByCurrency.Count);
        Assert.Equal(50m, Currency(result, "USD").TotalRevenue);
        Assert.Equal(20m, Currency(result, "BAM").TotalRevenue);
        Assert.Equal(30m, Currency(result, "XYZ").TotalRevenue);
        Assert.Equal(40m, Currency(result, "EUR").TotalRevenue);
        Assert.Equal(50m, result.TotalRevenue); // Legacy projection is USD only, never 140.
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("US$")]
    [InlineData("123")]
    [InlineData("TOOLONG")]
    public async Task Invalid_currency_is_explicit_and_never_becomes_usd(string? currency)
    {
        await using var s = new Scenario();
        s.Membership(20m, currency, January);
        var result = await s.ReportAsync();
        var unknown = Assert.Single(result.RevenueByCurrency);
        Assert.Null(unknown.Currency);
        Assert.StartsWith("invalid:", unknown.CurrencyKey);
        Assert.Contains("Unknown currency", unknown.CurrencyLabel);
        Assert.Equal(20m, unknown.TotalRevenue);
        Assert.Equal(0m, result.TotalRevenue);
    }

    [Fact]
    public async Task Different_invalid_codes_are_not_combined()
    {
        await using var s = new Scenario();
        s.Membership(20m, "US$", January);
        s.Membership(30m, "???", January);
        s.Membership(40m, null, January);
        var groups = (await s.ReportAsync()).RevenueByCurrency;
        Assert.Equal(3, groups.Count);
        Assert.Equal(3, groups.Select(x => x.CurrencyKey).Distinct().Count());
        Assert.All(groups, x => Assert.Null(x.Currency));
    }

    [Theory]
    [InlineData(PaymentStatus.Pending)]
    [InlineData(PaymentStatus.Paid)]
    [InlineData(PaymentStatus.Failed)]
    [InlineData(PaymentStatus.RefundPending)]
    [InlineData(PaymentStatus.RefundFailed)]
    [InlineData(PaymentStatus.Refunded)]
    public async Task Existing_status_filter_is_preserved_for_both_sources(PaymentStatus status)
    {
        await using var s = new Scenario();
        s.Direct(50m, January, status);
        s.Membership(20m, "USD", January, status);
        var result = await s.ReportAsync();
        if (status == PaymentStatus.Paid)
            Assert.Equal(70m, Assert.Single(result.RevenueByCurrency).TotalRevenue);
        else
            Assert.Empty(result.RevenueByCurrency);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task Deleted_or_undated_payments_are_excluded(bool deleted, bool undated)
    {
        await using var s = new Scenario();
        var direct = s.Direct(50m, undated ? null : January);
        var membership = s.Membership(20m, "USD", undated ? null : January);
        direct.IsDeleted = deleted;
        membership.IsDeleted = deleted;
        Assert.Empty((await s.ReportAsync()).RevenueByCurrency);
    }

    [Fact]
    public async Task Period_and_month_grouping_keep_the_existing_utc_boundaries()
    {
        await using var s = new Scenario();
        var from = January;
        var to = January.AddMonths(1);
        s.Direct(1m, from.AddTicks(-1));
        s.Direct(2m, from);
        s.Direct(4m, to);
        s.Direct(8m, to.AddTicks(1));
        s.Membership(20m, "BAM", from);
        var result = await s.ReportAsync(from, to);
        var usd = Currency(result, "USD");
        Assert.Equal(15m, usd.TotalRevenue);
        Assert.Equal(6m, usd.PeriodRevenue);
        Assert.Equal(new[] { "2026-01", "2026-02" }, usd.RevenueByMonth.Select(x => x.Label));
        Assert.Equal(new[] { 2m, 4m }, usd.RevenueByMonth.Select(x => x.Revenue));
        Assert.Equal(20m, Currency(result, "BAM").PeriodRevenue);
    }

    [Fact]
    public async Task Current_month_is_independent_of_selected_period_and_currency()
    {
        await using var s = new Scenario();
        var now = DateTime.UtcNow;
        var month = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        s.Direct(50m, month.AddHours(1));
        s.Direct(10m, month.AddTicks(-1));
        s.Membership(20m, "BAM", month.AddHours(1));
        var result = await s.ReportAsync(month.AddYears(-1), month.AddYears(-1).AddDays(1));
        Assert.Equal(50m, Currency(result, "USD").CurrentMonthRevenue);
        Assert.Equal(20m, Currency(result, "BAM").CurrentMonthRevenue);
        Assert.Equal(0m, Currency(result, "USD").PeriodRevenue);
    }

    [Fact]
    public async Task Empty_dashboard_has_no_fabricated_currency_transactions()
    {
        await using var s = new Scenario();
        var result = await s.ReportAsync();
        Assert.Empty(result.RevenueByCurrency);
        Assert.Empty(result.RevenueByMonth);
        Assert.Equal(0m, result.TotalRevenue);
        Assert.Equal(0m, result.CurrentMonthRevenue);
        Assert.Equal(0m, result.PeriodRevenue);
        Assert.Equal(0, result.TotalAppointments);
    }

    [Fact]
    public async Task Multiple_membership_usages_do_not_duplicate_payment_or_change_nonfinancial_metrics()
    {
        await using var s = new Scenario();
        var payment = s.Membership(20m, "USD", January);
        foreach (var status in new[] { AppointmentStatus.Completed, AppointmentStatus.Accepted })
        {
            var appointment = s.Appointment(status);
            s.Db.Add(new MembershipUsage { ClientMembership = payment.ClientMembership,
                Appointment = appointment, UsedAtUtc = January });
        }
        var result = await s.ReportAsync();
        Assert.Equal(20m, Assert.Single(result.RevenueByCurrency).TotalRevenue);
        Assert.Equal(2, result.TotalUsers);
        Assert.Equal(1, result.ActiveClients);
        Assert.Equal(1, result.TotalTherapists);
        Assert.Equal(2, result.TotalAppointments);
        Assert.Equal(1, result.CompletedAppointments);
        Assert.Equal(2, await s.Db.MembershipUsages.CountAsync());
        Assert.Empty(await s.Db.Payments.ToListAsync());
    }

    [Fact]
    public async Task Json_adds_currency_series_and_keeps_legacy_fields_as_usd_projection()
    {
        await using var s = new Scenario();
        var now = DateTime.UtcNow;
        var month = new DateTime(now.Year, now.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var paidAt = month.AddHours(1);
        s.Direct(50m, paidAt);
        s.Membership(20m, "BAM", paidAt);
        var result = await s.ReportAsync(month, month.AddMonths(1).AddTicks(-1));

        Assert.Equal("USD", result.RevenueCurrency);
        Assert.Equal(50m, result.TotalRevenue);
        Assert.Equal(50m, result.CurrentMonthRevenue);
        Assert.Equal(50m, result.PeriodRevenue);
        var compatibleMonth = Assert.Single(result.RevenueByMonth);
        Assert.Equal(month.Year, compatibleMonth.Year);
        Assert.Equal(month.Month, compatibleMonth.Month);
        Assert.Equal(50m, compatibleMonth.Revenue);

        var usd = Currency(result, "USD");
        var bam = Currency(result, "BAM");
        Assert.Equal(50m, usd.TotalRevenue);
        Assert.Equal(50m, usd.CurrentMonthRevenue);
        Assert.Equal(50m, usd.PeriodRevenue);
        Assert.Equal(50m, Assert.Single(usd.RevenueByMonth).Revenue);
        Assert.Equal(20m, bam.TotalRevenue);
        Assert.Equal(20m, bam.CurrentMonthRevenue);
        Assert.Equal(20m, bam.PeriodRevenue);
        Assert.Equal(20m, Assert.Single(bam.RevenueByMonth).Revenue);
        Assert.All(new[] { result.TotalRevenue, result.CurrentMonthRevenue,
            result.PeriodRevenue, compatibleMonth.Revenue }, amount => Assert.NotEqual(70m, amount));

        using var json = JsonDocument.Parse(JsonSerializer.Serialize(result,
            new JsonSerializerOptions(JsonSerializerDefaults.Web)));
        var root = json.RootElement;
        Assert.Equal(50m, root.GetProperty("totalRevenue").GetDecimal());
        Assert.Equal(50m, root.GetProperty("currentMonthRevenue").GetDecimal());
        Assert.Equal(50m, root.GetProperty("periodRevenue").GetDecimal());
        Assert.Equal("USD", root.GetProperty("revenueCurrency").GetString());
        Assert.Equal(2, root.GetProperty("revenueByCurrency").GetArrayLength());
        Assert.Equal(result.TotalUsers, root.GetProperty("totalUsers").GetInt32());
        Assert.Equal(50m, root.GetProperty("revenueByMonth")[0].GetProperty("revenue").GetDecimal());
    }

    private static AdminDashboardCurrencyRevenueDto Currency(AdminDashboardReportDto report, string code) =>
        Assert.Single(report.RevenueByCurrency, x => x.Currency == code);

    private sealed class Scenario : IAsyncDisposable
    {
        // Null checks disabled only to exercise corrupt/legacy currency input defensively.
        public ApplicationDbContext Db { get; } = new(new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase($"dashboard-currency-{Guid.NewGuid():N}", x => x.EnableNullChecks(false)).Options);
        private readonly Client client = new() { User = User("client") };
        private readonly Therapist therapist = new() { User = User("therapist"),
            Biography = "Synthetic", Specialization = "Test", HourlyRate = 90m };

        private static ApplicationUser User(string name) => new() { UserName = name + "@test.local",
            Email = name + "@test.local", FirstName = "Synthetic", LastName = name, IsActive = true };

        public Appointment Appointment(AppointmentStatus status = AppointmentStatus.Accepted)
        {
            var appointment = new Appointment { Client = client, Therapist = therapist,
                StartUtc = January, EndUtc = January.AddHours(1), Price = 50m, Status = status };
            Db.Add(appointment);
            return appointment;
        }

        public Payment Direct(decimal amount, DateTime? paidAt, PaymentStatus status = PaymentStatus.Paid)
        {
            var payment = new Payment { Appointment = Appointment(), Amount = amount,
                Status = status, PaidAtUtc = paidAt, StripePaymentIntentId = "pi_test_" + Guid.NewGuid() };
            Db.Add(payment);
            return payment;
        }

        public MembershipPayment Membership(decimal amount, string? currency, DateTime? paidAt,
            PaymentStatus status = PaymentStatus.Paid)
        {
            var payment = new MembershipPayment { ClientMembership = new ClientMembership {
                Client = client, Therapist = therapist, Price = amount, RemainingSessions = 4 },
                Amount = amount, Currency = currency!, Status = status, PaidAtUtc = paidAt,
                StripePaymentIntentId = "pi_membership_test_" + Guid.NewGuid() };
            Db.Add(payment);
            return payment;
        }

        public async Task<AdminDashboardReportDto> ReportAsync(DateTime? from = null, DateTime? to = null)
        {
            await Db.SaveChangesAsync();
            return await new AdminReportService(Db).GetDashboardReportAsync(new AdminDashboardReportQueryDto {
                FromUtc = from ?? new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc),
                ToUtc = to ?? new DateTime(2026, 12, 31, 23, 59, 59, DateTimeKind.Utc) });
        }

        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
}
