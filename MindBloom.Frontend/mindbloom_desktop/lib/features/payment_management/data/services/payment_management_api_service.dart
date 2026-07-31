import '../../../../core/network/api_client.dart';
import '../models/admin_payment_details_model.dart';
import '../models/admin_payment_paged_response.dart';
import '../models/admin_payment_receipt_model.dart';

class PaymentManagementApiService {
  final ApiClient apiClient;

  const PaymentManagementApiService({required this.apiClient});

  Future<AdminPaymentPagedResponse> getPayments({
    required int pageNumber,
    required int pageSize,
    String? search,
    int? status,
    String? paymentType,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minimumAmount,
    double? maximumAmount,
  }) async {
    final queryParameters = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    final normalizedPaymentType = paymentType?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      queryParameters['Search'] = normalizedSearch;
    }

    if (status != null) {
      queryParameters['Status'] = status.toString();
    }

    if (normalizedPaymentType.isNotEmpty) {
      queryParameters['PaymentType'] = normalizedPaymentType;
    }

    if (dateFrom != null) {
      queryParameters['DateFromUtc'] = dateFrom.toUtc().toIso8601String();
    }

    if (dateTo != null) {
      queryParameters['DateToUtc'] = dateTo.toUtc().toIso8601String();
    }

    if (minimumAmount != null) {
      queryParameters['MinimumAmount'] = minimumAmount.toString();
    }

    if (maximumAmount != null) {
      queryParameters['MaximumAmount'] = maximumAmount.toString();
    }

    final uri = Uri(path: '/Admin/payments', queryParameters: queryParameters);

    final response = await apiClient.get(uri.toString());

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid payment data.');
    }

    return AdminPaymentPagedResponse.fromJson(response);
  }

  Future<AdminPaymentDetailsModel> getPaymentDetails({
    required String paymentType,
    required int paymentId,
  }) async {
    final response = await apiClient.get(
      '/Admin/payments/'
      '${Uri.encodeComponent(paymentType)}/'
      '$paymentId',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid payment details.');
    }

    return AdminPaymentDetailsModel.fromJson(response);
  }

  Future<AdminPaymentReceiptModel> getPaymentReceipt({
    required String paymentType,
    required int paymentId,
  }) async {
    final response = await apiClient.get(
      '/Admin/payments/'
      '${Uri.encodeComponent(paymentType)}/'
      '$paymentId/receipt',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid receipt data.');
    }

    return AdminPaymentReceiptModel.fromJson(response);
  }

  Future<void> refundPayment({
    required String paymentType,
    required int paymentId,
    required String reason,
  }) async {
    await apiClient.put(
      '/Admin/payments/'
      '${Uri.encodeComponent(paymentType)}/'
      '$paymentId/refund',
      body: {'reason': reason},
    );
  }
}
