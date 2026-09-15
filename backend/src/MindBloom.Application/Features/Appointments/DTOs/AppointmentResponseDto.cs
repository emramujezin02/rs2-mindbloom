namespace MindBloom.Application.Features.Appointments.DTOs;

public class AppointmentResponseDto
{
    public int Id { get; set; }

    public int TherapistId { get; set; }

    public string TherapistName { get; set; } = null!;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Status { get; set; } = null!;

    public string Type { get; set; } = string.Empty;

    public decimal Price { get; set; }

    public string? MeetingLink { get; set; }

    public string? Location { get; set; }

    public int? PaymentId { get; set; }

    public int ClientId { get; set; }

    public string ClientName { get; set; } = string.Empty;

    public string ClientEmail { get; set; } = string.Empty;

    public string? Notes { get; set; }

    public bool CanAccessSession { get; set; }

    public string? SessionAccessMessage { get; set; }
}