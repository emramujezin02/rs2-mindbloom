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
    String? paymentType,
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
      paymentType: paymentType,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minimumAmount: minimumAmount,
      maximumAmount: maximumAmount,
    );
  }

  Future<AdminPaymentDetailsModel> getPaymentDetails({
    required String paymentType,
    required int paymentId,
  }) {
    return apiService.getPaymentDetails(
      paymentType: paymentType,
      paymentId: paymentId,
    );
  }

  Future<AdminPaymentReceiptModel> getPaymentReceipt({
    required String paymentType,
    required int paymentId,
  }) {
    return apiService.getPaymentReceipt(
      paymentType: paymentType,
      paymentId: paymentId,
    );
  }

  Future<void> refundPayment({
    required String paymentType,
    required int paymentId,
    required String reason,
  }) {
    return apiService.refundPayment(
      paymentType: paymentType,
      paymentId: paymentId,
      reason: reason,
    );
  }
}
