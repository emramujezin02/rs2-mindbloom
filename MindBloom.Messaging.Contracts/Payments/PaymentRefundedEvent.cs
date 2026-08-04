using MindBloom.Messaging.Contracts.Common;

namespace MindBloom.Messaging.Contracts.Payments;

public sealed record PaymentRefundedEvent
    : IntegrationEvent
{
    public int PaymentId { get; init; }

    public string PaymentType { get; init; } =
        string.Empty;

    public int? AppointmentId { get; init; }

    public int? MembershipId { get; init; }

    public int ClientUserId { get; init; }

    public decimal Amount { get; init; }

    public string Currency { get; init; } =
        string.Empty;

    public string? Reason { get; init; }

    public DateTime RefundedAtUtc { get; init; }
}