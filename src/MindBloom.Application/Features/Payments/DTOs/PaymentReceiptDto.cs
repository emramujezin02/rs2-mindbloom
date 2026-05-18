namespace MindBloom.Application.Features.Payments.DTOs;

public class PaymentReceiptDto
{
    public int PaymentId { get; set; }

    public decimal Amount { get; set; }

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
}