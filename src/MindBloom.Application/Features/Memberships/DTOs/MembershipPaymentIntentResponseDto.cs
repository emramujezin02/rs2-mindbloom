namespace MindBloom.Application.Features.Memberships.DTOs;

public class MembershipPaymentIntentResponseDto
{
    public int MembershipId { get; set; }

    public string ClientSecret { get; set; } = string.Empty;

    public string PaymentIntentId { get; set; } = string.Empty;

    public decimal Amount { get; set; }

    public string Currency { get; set; } = string.Empty;
}