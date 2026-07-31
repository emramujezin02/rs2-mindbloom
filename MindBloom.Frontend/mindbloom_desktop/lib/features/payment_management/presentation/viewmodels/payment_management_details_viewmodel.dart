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

  Future<void> load({
    required String paymentType,
    required int paymentId,
  }) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      payment = await repository.getPaymentDetails(
        paymentType: paymentType,
        paymentId: paymentId,
      );
    } catch (exception) {
      error = _cleanError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refund({
    required String paymentType,
    required int paymentId,
    required String reason,
  }) async {
    if (isRefunding) {
      return false;
    }

    isRefunding = true;
    error = null;
    notifyListeners();

    try {
      await repository.refundPayment(
        paymentType: paymentType,
        paymentId: paymentId,
        reason: reason,
      );

      payment = await repository.getPaymentDetails(
        paymentType: paymentType,
        paymentId: paymentId,
      );

      return true;
    } catch (exception) {
      error = _cleanError(exception);

      return false;
    } finally {
      isRefunding = false;
      notifyListeners();
    }
  }

  String _cleanError(Object errorValue) {
    final value = errorValue.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }
}
