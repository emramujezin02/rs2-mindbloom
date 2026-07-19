namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistClientListDto
{
    public int ClientId { get; set; }

    public int UserId { get; set; }

    public string FullName { get; set; }
        = string.Empty;

    public string Email { get; set; }
        = string.Empty;

    public string? PhoneNumber { get; set; }

    public int TotalAppointments { get; set; }

    public int CompletedAppointments { get; set; }

    public DateTime? LastAppointmentDate { get; set; }

    public DateTime? NextAppointmentDate { get; set; }
}