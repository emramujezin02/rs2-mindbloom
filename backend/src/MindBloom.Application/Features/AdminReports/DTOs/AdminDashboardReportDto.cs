namespace MindBloom.Application.Features.AdminReports.DTOs;

public class AdminDashboardReportDto
{
    public DateTime FromUtc { get; set; }

    public DateTime ToUtc { get; set; }

    public DateTime GeneratedAtUtc { get; set; }

    public int TotalUsers { get; set; }

    public int ActiveClients { get; set; }

    public int TotalTherapists { get; set; }

    public int VerifiedTherapists { get; set; }

    public int PendingTherapists { get; set; }

    public int TotalAppointments { get; set; }

    public int TodayAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public int CancelledAppointments { get; set; }

    // Compatibility fields are USD-only projections, never cross-currency totals.
    // New clients must use RevenueByCurrency; these are not net accounting revenue.
    public string RevenueCurrency => "USD";
    public decimal TotalRevenue => UsdRevenue?.TotalRevenue ?? 0m;
    public decimal CurrentMonthRevenue => UsdRevenue?.CurrentMonthRevenue ?? 0m;
    public decimal PeriodRevenue => UsdRevenue?.PeriodRevenue ?? 0m;
    private AdminDashboardCurrencyRevenueDto? UsdRevenue =>
        RevenueByCurrency.FirstOrDefault(x => x.Currency == "USD");

    public List<AdminDashboardCurrencyRevenueDto> RevenueByCurrency { get; set; } = [];

    public int ActiveMemberships { get; set; }

    public int PendingReviews { get; set; }

    public int PublishedArticles { get; set; }

    public int ActiveWorkshops { get; set; }

    public List<AdminDashboardCountItemDto>
        AppointmentsByStatus
    { get; set; } = [];

    // Same USD-only compatibility projection as the scalar fields above.
    public List<AdminDashboardMonthlyRevenueItemDto> RevenueByMonth =>
        UsdRevenue?.RevenueByMonth ?? [];

    public List<AdminDashboardMonthlyCountItemDto>
        NewUsersByMonth
    { get; set; } = [];

    public List<AdminDashboardCountItemDto>
    AppointmentsByTherapyApproach
    { get; set; } = [];

    public List<AdminDashboardMonthlyCountItemDto>
        VerifiedTherapistsByMonth
    { get; set; } = [];
}

public class AdminDashboardCurrencyRevenueDto
{
    // Currency is null for missing/invalid codes. Keys keep distinct invalid inputs separate.
    public string CurrencyKey { get; set; } = string.Empty;
    public string? Currency { get; set; }
    public string CurrencyLabel { get; set; } = string.Empty;
    public decimal TotalRevenue { get; set; }
    public decimal CurrentMonthRevenue { get; set; }
    public decimal PeriodRevenue { get; set; }
    public List<AdminDashboardMonthlyRevenueItemDto> RevenueByMonth { get; set; } = [];
}

public class AdminDashboardCountItemDto
{
    public string Label { get; set; } = string.Empty;

    public int Count { get; set; }
}

public class AdminDashboardMonthlyRevenueItemDto
{
    public int Year { get; set; }

    public int Month { get; set; }

    public string Label { get; set; } = string.Empty;

    public decimal Revenue { get; set; }
}

public class AdminDashboardMonthlyCountItemDto
{
    public int Year { get; set; }

    public int Month { get; set; }

    public string Label { get; set; } = string.Empty;

    public int Count { get; set; }
}
