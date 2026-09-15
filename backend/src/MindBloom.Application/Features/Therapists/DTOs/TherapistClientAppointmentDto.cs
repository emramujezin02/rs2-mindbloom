namespace MindBloom.Application.Features.Therapists.DTOs;

public class TherapistClientAppointmentDto
{
    public int AppointmentId { get; set; }

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Status { get; set; }
        = string.Empty;

    public string Type { get; set; }
        = string.Empty;

    public string? MeetingLink { get; set; }

    public string? Location { get; set; }

    public bool HasNote { get; set; }
}