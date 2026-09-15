import '../models/confirm_payment_request.dart';
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

  Future<List<PaymentModel>> getMyPayments() {
    return apiService.getMyPayments();
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
    final payments = await apiService.getMyPayments();

    for (final payment in payments) {
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
