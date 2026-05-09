namespace MindBloom.Application.Features.Payments.DTOs;

public class PaymentIntentResponseDto
{
    public string ClientSecret { get; set; } = null!;

    public string PaymentIntentId { get; set; } = null!;
}