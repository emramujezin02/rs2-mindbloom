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
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minimumAmount,
    double? maximumAmount,
  }) async {
    final queryParameters = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['Search'] = search.trim();
    }

    if (status != null) {
      queryParameters['Status'] = status.toString();
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

    final queryString = Uri(queryParameters: queryParameters).query;

    final response = await apiClient.get('/Admin/payments?$queryString');

    return AdminPaymentPagedResponse.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<AdminPaymentDetailsModel> getPaymentDetails(int paymentId) async {
    final response = await apiClient.get('/Admin/payments/$paymentId');

    return AdminPaymentDetailsModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<AdminPaymentReceiptModel> getPaymentReceipt(int paymentId) async {
    final response = await apiClient.get(
      '/Admin/payments/'
      '$paymentId/receipt',
    );

    return AdminPaymentReceiptModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> refundPayment({
    required int paymentId,
    required String reason,
  }) async {
    await apiClient.put(
      '/Admin/payments/'
      '$paymentId/refund',
      body: {'reason': reason},
    );
  }
}
