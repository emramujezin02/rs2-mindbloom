namespace MindBloom.Application.Features.Appointments.DTOs;

public class ClientDashboardDto
{
    public int TotalAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public int PendingAppointments { get; set; }

    public int CancelledAppointments { get; set; }

    public int TotalTherapistsVisited { get; set; }

    public decimal TotalSpent { get; set; }

    public DateTime? LastAppointmentDate { get; set; }

    public DateTime? NextAppointmentDate { get; set; }
}