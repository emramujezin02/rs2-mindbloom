import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/admin_payment_model.dart';
import '../../data/repositories/payment_management_repository.dart';

class PaymentManagementViewModel extends ChangeNotifier {
  final PaymentManagementRepository repository;

  PaymentManagementViewModel({required this.repository});

  Timer? _searchDebounce;

  bool isLoading = false;

  String? error;

  List<AdminPaymentModel> payments = [];

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String currentSearch = '';

  int? currentStatus;

  String? currentPaymentType;

  DateTime? currentDateFrom;

  DateTime? currentDateTo;

  double? currentMinimumAmount;

  double? currentMaximumAmount;

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> load({
    int? requestedPage,
    String? search,
    int? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minimumAmount,
    double? maximumAmount,
    String? paymentType,
    bool updateFilters = false,
    bool clearCurrentResults = false,
  }) async {
    if (isLoading) {
      return;
    }

    if (clearCurrentResults) {
      payments = [];
      totalCount = 0;
      totalPages = 0;
    }

    if (updateFilters) {
      currentSearch = search?.trim() ?? '';

      currentStatus = status;

      currentPaymentType = _normalizeText(paymentType);

      currentDateFrom = dateFrom;

      currentDateTo = dateTo;

      currentMinimumAmount = minimumAmount;

      currentMaximumAmount = maximumAmount;
    }

    isLoading = true;

    error = null;

    if (clearCurrentResults) {
      payments = [];

      totalCount = 0;

      totalPages = 0;
    }

    notifyListeners();

    try {
      final response = await repository.getPayments(
        pageNumber: requestedPage ?? pageNumber,
        pageSize: pageSize,
        search: currentSearch,
        status: currentStatus,
        dateFrom: currentDateFrom,
        dateTo: currentDateTo,
        minimumAmount: currentMinimumAmount,
        maximumAmount: currentMaximumAmount,
        paymentType: currentPaymentType,
      );

      payments = response.items;

      pageNumber = response.pageNumber == 0 ? 1 : response.pageNumber;

      pageSize = response.pageSize == 0 ? pageSize : response.pageSize;

      totalCount = response.totalCount;

      totalPages = response.totalPages;
    } catch (exception) {
      payments = [];

      totalCount = 0;

      totalPages = 0;

      error = AppErrorHelper.message(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void updateSearch(String value) {
    currentSearch = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      load(
        requestedPage: 1,
        search: currentSearch,
        status: currentStatus,
        paymentType: currentPaymentType,
        dateFrom: currentDateFrom,
        dateTo: currentDateTo,
        minimumAmount: currentMinimumAmount,
        maximumAmount: currentMaximumAmount,
        clearCurrentResults: true,
      );
    });
  }

  Future<void> applyFilters({
    required String search,
    int? status,
    String? paymentType,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minimumAmount,
    double? maximumAmount,
  }) {
    _searchDebounce?.cancel();

    return load(
      requestedPage: 1,
      search: search,
      status: status,
      paymentType: paymentType,
      dateFrom: dateFrom,
      dateTo: dateTo,
      minimumAmount: minimumAmount,
      maximumAmount: maximumAmount,
      updateFilters: true,
      clearCurrentResults: true,
    );
  }

  Future<void> clearFilters() {
    _searchDebounce?.cancel();

    currentSearch = '';

    currentStatus = null;

    currentPaymentType = null;

    currentDateFrom = null;

    currentDateTo = null;

    currentMinimumAmount = null;

    currentMaximumAmount = null;

    return load(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> reload() {
    return load(requestedPage: pageNumber);
  }

  Future<void> changePageSize(int value) {
    if (value == pageSize) {
      return Future.value();
    }

    pageSize = value;

    return load(
      requestedPage: 1,
      search: currentSearch,
      status: currentStatus,
      paymentType: currentPaymentType,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      minimumAmount: currentMinimumAmount,
      maximumAmount: currentMaximumAmount,
      clearCurrentResults: true,
    );
  }

  Future<void> nextPage() {
    if (!hasNextPage || isLoading) {
      return Future.value();
    }

    return load(requestedPage: pageNumber + 1);
  }

  Future<void> previousPage() {
    if (!hasPreviousPage || isLoading) {
      return Future.value();
    }

    return load(requestedPage: pageNumber - 1);
  }

  String? _normalizeText(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
  }

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
