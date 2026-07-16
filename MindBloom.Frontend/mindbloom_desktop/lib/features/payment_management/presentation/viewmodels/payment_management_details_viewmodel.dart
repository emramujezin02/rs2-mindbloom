import 'package:flutter/foundation.dart';

import '../../data/models/admin_payment_details_model.dart';
import '../../data/repositories/payment_management_repository.dart';

class PaymentManagementDetailsViewModel extends ChangeNotifier {
  final PaymentManagementRepository repository;

  PaymentManagementDetailsViewModel({required this.repository});

  bool isLoading = false;

  bool isRefunding = false;

  String? error;

  AdminPaymentDetailsModel? payment;

  Future<void> load(int paymentId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      payment = await repository.getPaymentDetails(paymentId);
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> refund({required int paymentId, required String reason}) async {
    isRefunding = true;
    error = null;
    notifyListeners();

    try {
      await repository.refundPayment(paymentId: paymentId, reason: reason);

      payment = await repository.getPaymentDetails(paymentId);

      isRefunding = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isRefunding = false;
      notifyListeners();

      return false;
    }
  }
}
