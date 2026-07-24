using MindBloom.Domain.Enums;

namespace MindBloom.Application.Features.Appointments.DTOs;

public class CreateAppointmentDto
{
    public int TherapistId { get; set; }

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public AppointmentType Type { get; set; }

    public string? MeetingLink { get; set; }

    public string? Location { get; set; }

    public string? Notes { get; set; }
}