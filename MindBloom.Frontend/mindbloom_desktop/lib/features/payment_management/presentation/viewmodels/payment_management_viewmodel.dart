import 'package:flutter/foundation.dart';

import '../../data/models/admin_payment_model.dart';
import '../../data/repositories/payment_management_repository.dart';

class PaymentManagementViewModel extends ChangeNotifier {
  final PaymentManagementRepository repository;

  PaymentManagementViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  List<AdminPaymentModel> payments = [];

  int pageNumber = 1;

  final int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String? currentSearch;

  int? currentStatus;

  DateTime? currentDateFrom;

  DateTime? currentDateTo;

  double? currentMinimumAmount;

  double? currentMaximumAmount;

  Future<void> load({
    int requestedPage = 1,
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minimumAmount,
    double? maximumAmount,
  }) async {
    isLoading = true;
    error = null;

    currentSearch = search;
    currentStatus = status;
    currentDateFrom = dateFrom;
    currentDateTo = dateTo;
    currentMinimumAmount = minimumAmount;
    currentMaximumAmount = maximumAmount;

    notifyListeners();

    try {
      final response = await repository.getPayments(
        pageNumber: requestedPage,
        pageSize: pageSize,
        search: search,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
        minimumAmount: minimumAmount,
        maximumAmount: maximumAmount,
      );

      payments = response.items;
      pageNumber = response.pageNumber;
      totalCount = response.totalCount;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> reload() {
    return load(
      requestedPage: pageNumber,
      search: currentSearch,
      status: currentStatus,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      minimumAmount: currentMinimumAmount,
      maximumAmount: currentMaximumAmount,
    );
  }

  Future<void> nextPage() async {
    if (isLoading || pageNumber >= totalPages) {
      return;
    }

    await load(
      requestedPage: pageNumber + 1,
      search: currentSearch,
      status: currentStatus,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      minimumAmount: currentMinimumAmount,
      maximumAmount: currentMaximumAmount,
    );
  }

  Future<void> previousPage() async {
    if (isLoading || pageNumber <= 1) {
      return;
    }

    await load(
      requestedPage: pageNumber - 1,
      search: currentSearch,
      status: currentStatus,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      minimumAmount: currentMinimumAmount,
      maximumAmount: currentMaximumAmount,
    );
  }
}
