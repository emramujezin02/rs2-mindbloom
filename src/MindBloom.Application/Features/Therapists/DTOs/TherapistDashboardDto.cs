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
}