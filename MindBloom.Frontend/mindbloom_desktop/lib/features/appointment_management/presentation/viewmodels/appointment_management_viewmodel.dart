import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/admin_appointment_model.dart';
import '../../data/repositories/appointment_management_repository.dart';

class AppointmentManagementViewModel extends ChangeNotifier {
  final AppointmentManagementRepository repository;

  AppointmentManagementViewModel({required this.repository});

  Timer? _searchDebounce;

  bool isLoading = false;

  String? error;

  List<AdminAppointmentModel> appointments = [];

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String currentSearch = '';

  String? currentStatus;

  String? currentType;

  DateTime? currentDateFrom;

  DateTime? currentDateTo;

  bool? currentIsPaid;

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> load({
    int? requestedPage,
    String? search,
    String? status,
    String? type,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? isPaid,
    bool updateFilters = false,
    bool clearCurrentResults = false,
  }) async {
    if (isLoading) {
      return;
    }

    if (updateFilters) {
      currentSearch = search?.trim() ?? '';

      currentStatus = _normalizeText(status);

      currentType = _normalizeText(type);

      currentDateFrom = dateFrom;

      currentDateTo = dateTo;

      currentIsPaid = isPaid;
    }

    isLoading = true;

    error = null;

    if (clearCurrentResults) {
      appointments = [];

      totalCount = 0;

      totalPages = 0;
    }

    notifyListeners();

    try {
      final response = await repository.getAppointments(
        pageNumber: requestedPage ?? pageNumber,
        pageSize: pageSize,
        search: currentSearch,
        status: currentStatus,
        type: currentType,
        dateFrom: currentDateFrom,
        dateTo: currentDateTo,
        isPaid: currentIsPaid,
      );

      appointments = response.items;

      pageNumber = response.pageNumber == 0 ? 1 : response.pageNumber;

      pageSize = response.pageSize == 0 ? pageSize : response.pageSize;

      totalCount = response.totalCount;

      totalPages = response.totalPages;
    } catch (exception) {
      appointments = [];

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
        type: currentType,
        dateFrom: currentDateFrom,
        dateTo: currentDateTo,
        isPaid: currentIsPaid,
        clearCurrentResults: true,
      );
    });
  }

  Future<void> applyFilters({
    required String search,
    String? status,
    String? type,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? isPaid,
  }) {
    _searchDebounce?.cancel();

    return load(
      requestedPage: 1,
      search: search,
      status: status,
      type: type,
      dateFrom: dateFrom,
      dateTo: dateTo,
      isPaid: isPaid,
      updateFilters: true,
      clearCurrentResults: true,
    );
  }

  Future<void> clearFilters() {
    _searchDebounce?.cancel();

    currentSearch = '';

    currentStatus = null;

    currentType = null;

    currentDateFrom = null;

    currentDateTo = null;

    currentIsPaid = null;

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
      type: currentType,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      isPaid: currentIsPaid,
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
