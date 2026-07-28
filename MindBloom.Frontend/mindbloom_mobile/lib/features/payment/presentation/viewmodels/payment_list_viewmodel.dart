import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/payment_receipt_model.dart';
import '../../data/repositories/payment_repository.dart';

class PaymentListViewModel extends ChangeNotifier {
  final PaymentRepository repository;

  PaymentListViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingReceipt = false;

  String? error;
  String? receiptError;

  List<PaymentModel> payments = [];

  PaymentReceiptModel? receipt;

  Future<void> loadPayments() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final loadedPayments = await repository.getMyPayments();

      payments = loadedPayments;
      error = null;
    } catch (exception) {
      error = AppErrorMessage.from(
        exception,
        fallback: 'Payments could not be loaded.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadReceipt(int paymentId) async {
    if (isLoadingReceipt) {
      return;
    }

    isLoadingReceipt = true;
    receiptError = null;
    notifyListeners();

    try {
      final loadedReceipt = await repository.getReceipt(paymentId);

      receipt = loadedReceipt;
      receiptError = null;
    } catch (exception) {
      receiptError = AppErrorMessage.from(
        exception,
        fallback: 'Payment receipt could not be loaded.',
      );
    } finally {
      isLoadingReceipt = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;
    notifyListeners();
  }

  void clearReceiptError() {
    if (receiptError == null) {
      return;
    }

    receiptError = null;
    notifyListeners();
  }
}
