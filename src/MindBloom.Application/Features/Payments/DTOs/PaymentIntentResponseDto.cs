namespace MindBloom.Application.Features.Payments.DTOs;

public class PaymentIntentResponseDto
{
    public string ClientSecret { get; set; }
        = string.Empty;

    public string PaymentIntentId { get; set; }
        = string.Empty;

    public int AppointmentId { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; }
        = string.Empty;

    public string Purpose { get; set; }
        = string.Empty;
}