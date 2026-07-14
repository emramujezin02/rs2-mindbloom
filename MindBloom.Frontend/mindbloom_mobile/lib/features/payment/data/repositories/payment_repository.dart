import '../models/confirm_payment_request.dart';
import '../models/create_payment_intent_request.dart';
import '../models/payment_intent_response.dart';
import '../models/payment_model.dart';
import '../services/payment_api_service.dart';
import '../models/payment_receipt_model.dart';

class PaymentRepository {
  final PaymentApiService apiService;

  PaymentRepository({required this.apiService});

  Future<List<PaymentModel>> getMyPayments() {
    return apiService.getMyPayments();
  }

  Future<PaymentIntentResponse> createPaymentIntent(int appointmentId) {
    return apiService.createPaymentIntent(
      CreatePaymentIntentRequest(appointmentId: appointmentId),
    );
  }

  Future<void> confirmPayment(String paymentIntentId) {
    return apiService.confirmPayment(
      ConfirmPaymentRequest(paymentIntentId: paymentIntentId),
    );
  }

  Future<bool> isAppointmentPaid(int appointmentId) async {
    final payments = await apiService.getMyPayments();

    return payments.any(
      (payment) => payment.appointmentId == appointmentId && payment.isPaid,
    );
  }

  Future<PaymentReceiptModel> getReceipt(int paymentId) {
    return apiService.getReceipt(paymentId);
  }
}
