import 'package:flutter/material.dart';
import '../../data/models/payment_receipt_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/repositories/payment_repository.dart';

class PaymentListViewModel extends ChangeNotifier {
  final PaymentRepository repository;

  PaymentListViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  List<PaymentModel> payments = [];

  Future<void> loadPayments() async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      payments = await repository.getMyPayments();
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<PaymentReceiptModel> loadReceipt(int paymentId) {
    return repository.getReceipt(paymentId);
  }
}
