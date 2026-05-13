namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistDashboardDto
{
    public int TotalAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public int PendingAppointments { get; set; }

    public double AverageRating { get; set; }

    public int TotalReviews { get; set; }

    public decimal TotalEarnings { get; set; }
}