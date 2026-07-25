import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/payment_receipt_model.dart';
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
      error = _normalizeError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<PaymentReceiptModel> loadReceipt(int paymentId) {
    return repository.getReceipt(paymentId);
  }

  String _normalizeError(Object exception) {
    if (exception is AppException) {
      return exception.message;
    }

    final message = exception.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}
