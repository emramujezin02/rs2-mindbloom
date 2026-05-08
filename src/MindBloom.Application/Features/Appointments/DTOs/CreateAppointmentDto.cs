namespace MindBloom.Application.Features.Appointments.DTOs;

public class CreateAppointmentDto
{
    public int TherapistId { get; set; }

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }
}