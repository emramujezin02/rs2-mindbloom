namespace MindBloom.Application.Features.Payments.DTOs;

public class PaymentHistoryDto
{
    public int Id { get; set; }

    public decimal Amount { get; set; }

    public string Status { get; set; }
        = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public int AppointmentId { get; set; }

    public string TherapistName { get; set; }
        = string.Empty;
}