import '../models/confirm_payment_request.dart';
import '../../../../core/models/paged_response.dart';
import '../models/create_payment_intent_request.dart';
import '../models/payment_intent_response.dart';
import '../models/payment_model.dart';
import '../models/payment_receipt_model.dart';
import '../services/payment_api_service.dart';
import '../../../../core/network/idempotency_key_generator.dart';

class PaymentRepository {
  final PaymentApiService apiService;
  final Map<int, String> _paymentIntentKeys = <int, String>{};

  PaymentRepository({required this.apiService});

  Future<PagedResponse<PaymentModel>> getMyPayments({
    required int pageNumber,
    required int pageSize,
  }) {
    return apiService.getMyPayments(
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<PaymentIntentResponse> createPaymentIntent(int appointmentId) async {
    final idempotencyKey = _paymentIntentKeys.putIfAbsent(
      appointmentId,
      IdempotencyKeyGenerator.generate,
    );

    try {
      final result = await apiService.createPaymentIntent(
        CreatePaymentIntentRequest(appointmentId: appointmentId),
        idempotencyKey: idempotencyKey,
      );

      _paymentIntentKeys.remove(appointmentId);

      return result;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> confirmPayment(String paymentIntentId) {
    return apiService.confirmPayment(
      ConfirmPaymentRequest(paymentIntentId: paymentIntentId),
    );
  }

  Future<PaymentReceiptModel> getReceipt(int paymentId) {
    return apiService.getReceipt(paymentId);
  }

  Future<PaymentModel?> getPaymentForAppointment(int appointmentId) async {
    final payments = await apiService.getMyPayments(
      pageNumber: 1,
      pageSize: 1,
      appointmentId: appointmentId,
    );

    for (final payment in payments.items) {
      if (payment.appointmentId == appointmentId) {
        return payment;
      }
    }

    return null;
  }

  Future<bool> isAppointmentPaid(int appointmentId) async {
    final payment = await getPaymentForAppointment(appointmentId);

    return payment?.isPaid == true;
  }
}
