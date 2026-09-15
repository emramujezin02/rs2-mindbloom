using MindBloom.Domain.Enums;

namespace MindBloom.Domain.Entities;

public class MembershipPayment : BaseEntity
{
    public int ClientMembershipId { get; set; }

    public ClientMembership ClientMembership { get; set; } = null!;

    public decimal Amount { get; set; }

    public string Currency { get; set; } = "usd";

    public PaymentStatus Status { get; set; }

    public string StripePaymentIntentId { get; set; } = string.Empty;

    public DateTime? PaidAtUtc { get; set; }
}