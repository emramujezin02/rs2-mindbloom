import '../models/admin_payment_details_model.dart';
import '../models/admin_payment_paged_response.dart';
import '../models/admin_payment_receipt_model.dart';
import '../services/payment_management_api_service.dart';

class PaymentManagementRepository {
  final PaymentManagementApiService apiService;

  const PaymentManagementRepository({required this.apiService});

  Future<AdminPaymentPagedResponse> getPayments({
    required int pageNumber,
    required int pageSize,
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minimumAmount,
    double? maximumAmount,
  }) {
    return apiService.getPayments(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      status: status,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minimumAmount: minimumAmount,
      maximumAmount: maximumAmount,
    );
  }

  Future<AdminPaymentDetailsModel> getPaymentDetails(int paymentId) {
    return apiService.getPaymentDetails(paymentId);
  }

  Future<AdminPaymentReceiptModel> getPaymentReceipt(int paymentId) {
    return apiService.getPaymentReceipt(paymentId);
  }

  Future<void> refundPayment({required int paymentId, required String reason}) {
    return apiService.refundPayment(paymentId: paymentId, reason: reason);
  }
}
