using MindBloom.Application.Features.Payments.DTOs;

using MindBloom.Application.Common.Models;

namespace MindBloom.Application.Features.Payments.Interfaces;

public interface IPaymentService
{
    Task<PaymentIntentResponseDto>
        CreatePaymentIntentAsync(
            int clientUserId,
            CreatePaymentIntentDto request);

    Task ConfirmPaymentAsync(
        int clientUserId,
        ConfirmPaymentDto request);

    Task<PagedResponse<PaymentHistoryDto>>
        GetMyPaymentsAsync(
            int clientUserId,
            int pageNumber,
            int pageSize,
            int? appointmentId);

    Task<PaymentReceiptDto>
        GetReceiptAsync(
            int paymentId,
            int clientUserId);

    Task RefundAppointmentPaymentAsync(
        int clientUserId,
        int appointmentId,
        string reason);
}
