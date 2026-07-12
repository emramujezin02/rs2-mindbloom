using MindBloom.Application.Features.Payments.DTOs;

namespace MindBloom.Application.Features.Payments.Interfaces;

public interface IPaymentService
{
    Task<PaymentIntentResponseDto> CreatePaymentIntentAsync(int clientUserId, CreatePaymentIntentDto request);

    Task ConfirmPaymentAsync(ConfirmPaymentDto request);

    Task<List<PaymentHistoryDto>>GetMyPaymentsAsync(int clientUserId);

    Task<PaymentReceiptDto>
    GetReceiptAsync(
        int paymentId,
        int clientUserId);

    Task RefundAppointmentPaymentAsync(
    int clientUserId,
    int appointmentId,
    string reason);
}