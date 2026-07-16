namespace MindBloom.Application.Features.Admin.DTOs;

public class AdminAppointmentListDto
{
    public int Id { get; set; }

    public string ClientName { get; set; }
        = string.Empty;

    public string ClientEmail { get; set; }
        = string.Empty;

    public string TherapistName { get; set; }
        = string.Empty;

    public string TherapistEmail { get; set; }
        = string.Empty;

    public DateTime StartUtc { get; set; }

    public DateTime EndUtc { get; set; }

    public string Status { get; set; }
        = string.Empty;

    public string Type { get; set; }
        = string.Empty;

    public decimal Price { get; set; }

    public bool IsPaid { get; set; }

    public string? PaymentStatus { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public bool CanAdminCancel { get; set; }
}