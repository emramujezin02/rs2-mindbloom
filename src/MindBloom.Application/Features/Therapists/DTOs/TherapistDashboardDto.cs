namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistDashboardDto
{
    public int TodayAppointments { get; set; }

    public int UpcomingAppointments { get; set; }

    public int TotalClients { get; set; }

    public int NewRequests { get; set; }

    public int UnreadMessages { get; set; }

    public double AverageRating { get; set; }

    public decimal TotalEarnings { get; set; }

    public int NewClients { get; set; }

    public int ActiveClients { get; set; }

    public double AverageAppointmentsPerMonth { get; set; }

    public List<TherapistWorkTrendDto> WorkTrend { get; set; } = [];
}

public class TherapistWorkTrendDto
{
    public int Year { get; set; }

    public int Month { get; set; }

    public string Label { get; set; } = string.Empty;

    public int CompletedAppointments { get; set; }
}