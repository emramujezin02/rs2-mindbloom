import '../../../../core/network/api_client.dart';
import '../models/confirm_payment_request.dart';
import '../models/create_payment_intent_request.dart';
import '../models/payment_intent_response.dart';
import '../models/payment_model.dart';
import '../models/payment_receipt_model.dart';
import '../../../../core/network/idempotency_key_generator.dart';

class PaymentApiService {
  final ApiClient apiClient;

  PaymentApiService({required this.apiClient});

  Future<List<PaymentModel>> getMyPayments() async {
    final response = await apiClient.get('/Payments/mine');

    return (response as List)
        .map((item) => PaymentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentIntentResponse> createPaymentIntent(
    CreatePaymentIntentRequest request, {
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? IdempotencyKeyGenerator.generate();

    final response = await apiClient.post(
      '/Payments/create-intent',
      body: request.toJson(),
      idempotencyKey: key,
    );

    return PaymentIntentResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<void> confirmPayment(ConfirmPaymentRequest request) async {
    await apiClient.post('/Payments/confirm', body: request.toJson());
  }

  Future<PaymentReceiptModel> getReceipt(int paymentId) async {
    final response = await apiClient.get('/Payments/$paymentId/receipt');

    return PaymentReceiptModel.fromJson(response);
  }
}
