import '../../../../core/network/api_client.dart';
import '../../../../core/models/paged_response.dart';
import '../models/confirm_payment_request.dart';
import '../models/create_payment_intent_request.dart';
import '../models/payment_intent_response.dart';
import '../models/payment_model.dart';
import '../models/payment_receipt_model.dart';
import '../../../../core/network/idempotency_key_generator.dart';

class PaymentApiService {
  final ApiClient apiClient;

  PaymentApiService({required this.apiClient});

  Future<PagedResponse<PaymentModel>> getMyPayments({
    required int pageNumber,
    required int pageSize,
    int? appointmentId,
  }) async {
    final query = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (appointmentId != null) 'appointmentId': appointmentId.toString(),
    };

    final response = await apiClient.get(
      Uri(path: '/Payments/mine', queryParameters: query).toString(),
    );

    return PagedResponse.fromJson(
      response as Map<String, dynamic>,
      PaymentModel.fromJson,
    );
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
