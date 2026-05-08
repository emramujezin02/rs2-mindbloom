namespace MindBloom.Application.Features.Appointments.DTOs;

public class AppointmentResponseDto
{
    public int Id { get; set; }

    public int TherapistId { get; set; }

    public string TherapistName { get; set; } = null!;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Status { get; set; } = null!;
}