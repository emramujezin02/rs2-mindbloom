namespace MindBloom.Application.Features.Payments.DTOs;

public class PaymentReceiptDto
{
    public int PaymentId { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; }
        = string.Empty;

    public string Purpose { get; set; }
        = string.Empty;

    public string Status { get; set; }
        = string.Empty;

    public DateTime PaymentDateUtc
    {
        get;
        set;
    }

    public int AppointmentId { get; set; }

    public DateTime AppointmentStartUtc
    {
        get;
        set;
    }

    public DateTime AppointmentEndUtc
    {
        get;
        set;
    }

    public string TherapistName
    {
        get;
        set;
    } = string.Empty;

    public string ClientName
    {
        get;
        set;
    } = string.Empty;

    public string InvoiceNumber
    {
        get;
        set;
    } = string.Empty;

    public string StripePaymentIntentId
    {
        get;
        set;
    } = string.Empty;

    public string? StripeRefundId { get; set; }

    public string? RefundReason { get; set; }

    public DateTime? RefundRequestedAtUtc
    {
        get;
        set;
    }

    public DateTime? RefundedAtUtc
    {
        get;
        set;
    }

    public string? RefundFailureReason
    {
        get;
        set;
    }
}