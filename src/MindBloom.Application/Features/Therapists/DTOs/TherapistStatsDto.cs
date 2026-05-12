namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistStatsDto
{
    public int TotalAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public int CancelledAppointments { get; set; }

    public decimal TotalEarnings { get; set; }
}