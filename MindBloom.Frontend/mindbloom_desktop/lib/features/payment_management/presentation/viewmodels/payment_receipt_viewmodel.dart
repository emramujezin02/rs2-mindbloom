import 'package:flutter/foundation.dart';

import '../../data/models/admin_payment_receipt_model.dart';
import '../../data/repositories/payment_management_repository.dart';

class PaymentReceiptViewModel extends ChangeNotifier {
  final PaymentManagementRepository repository;

  PaymentReceiptViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  AdminPaymentReceiptModel? receipt;

  Future<void> load(int paymentId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      receipt = await repository.getPaymentReceipt(paymentId);
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
