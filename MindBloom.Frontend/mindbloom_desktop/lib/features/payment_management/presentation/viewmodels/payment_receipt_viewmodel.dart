import 'package:flutter/foundation.dart';

import '../../data/models/admin_payment_receipt_model.dart';
import '../../data/repositories/payment_management_repository.dart';

class PaymentReceiptViewModel extends ChangeNotifier {
  final PaymentManagementRepository repository;

  PaymentReceiptViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  AdminPaymentReceiptModel? receipt;

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
      receipt = await repository.getPaymentReceipt(
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

  String _cleanError(Object errorValue) {
    final value = errorValue.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }
}
