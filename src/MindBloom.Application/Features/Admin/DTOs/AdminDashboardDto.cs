namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminDashboardDto
{
    public int TotalUsers { get; set; }

    public int TotalClients { get; set; }

    public int TotalTherapists { get; set; }

    public int PendingTherapists
    {
        get;
        set;
    }

    public int ApprovedTherapists
    {
        get;
        set;
    }

    public int RejectedTherapists
    {
        get;
        set;
    }

    public int TotalAppointments
    {
        get;
        set;
    }

    public int CompletedAppointments
    {
        get;
        set;
    }

    public int PendingAppointments
    {
        get;
        set;
    }

    public int CancelledAppointments
    {
        get;
        set;
    }

    public int TotalReviews { get; set; }

    public int TotalPayments { get; set; }

    public decimal TotalRevenue
    {
        get;
        set;
    }
}