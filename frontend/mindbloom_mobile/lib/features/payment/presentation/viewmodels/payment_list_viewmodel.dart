import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/payment_receipt_model.dart';
import '../../data/repositories/payment_repository.dart';

class PaymentListViewModel extends ChangeNotifier {
  static const int pageSize = 10;

  final PaymentRepository repository;

  PaymentListViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingReceipt = false;

  String? error;
  String? loadMoreError;
  String? receiptError;

  List<PaymentModel> payments = [];

  PaymentReceiptModel? receipt;

  int pageNumber = 1;
  int totalPages = 0;

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadPayments() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    loadMoreError = null;
    pageNumber = 1;
    notifyListeners();

    try {
      final response = await repository.getMyPayments(
        pageNumber: 1,
        pageSize: pageSize,
      );

      payments = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
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

  Future<void> loadMorePayments() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getMyPayments(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
      );

      final existingIds = payments
          .map((payment) => '${payment.displayType}-${payment.id}')
          .toSet();

      payments.addAll(
        response.items.where(
          (payment) =>
              !existingIds.contains('${payment.displayType}-${payment.id}'),
        ),
      );

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      loadMoreError = AppErrorMessage.from(
        exception,
        fallback: 'More payments could not be loaded.',
      );
    } finally {
      isLoadingMore = false;
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
    loadMoreError = null;
    notifyListeners();
  }

  void clearLoadMoreError() {
    if (loadMoreError == null) {
      return;
    }

    loadMoreError = null;
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
