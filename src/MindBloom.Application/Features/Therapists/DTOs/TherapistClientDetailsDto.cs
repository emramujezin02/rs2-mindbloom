namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistClientDetailsDto
{
    public int ClientId { get; set; }

    public int UserId { get; set; }

    public string FullName { get; set; }
        = string.Empty;

    public string Email { get; set; }
        = string.Empty;

    public string? PhoneNumber { get; set; }

    public int TotalAppointments { get; set; }

    public int PendingAppointments { get; set; }

    public int AcceptedAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public int CancelledAppointments { get; set; }

    public DateTime? FirstAppointmentDate { get; set; }

    public DateTime? LastAppointmentDate { get; set; }

    public DateTime? NextAppointmentDate { get; set; }

    public List<TherapistClientAppointmentDto>
        AppointmentHistory
    { get; set; } = [];

    public List<TherapistClientMembershipDto>
    Memberships
    { get; set; } = [];

    public List<TherapistClientReviewDto>
        Reviews
    { get; set; } = [];
}