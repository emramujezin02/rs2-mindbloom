import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/admin_audit_filter_options_model.dart';
import '../../data/models/admin_audit_log_model.dart';
import '../../data/repositories/admin_audit_repository.dart';

class AdminAuditViewModel extends ChangeNotifier {
  final AdminAuditRepository repository;

  AdminAuditViewModel({required this.repository});

  Timer? _searchDebounce;

  bool isLoading = false;
  bool isLoadingFilters = false;

  String? errorMessage;

  List<AdminAuditLogModel> logs = [];

  List<AdminAuditUserOptionModel> users = [];

  List<String> actions = [];

  List<String> entityTypes = [];

  String search = '';

  int? selectedAdminUserId;

  String? selectedAction;

  String? selectedEntityType;

  DateTime? fromUtc;

  DateTime? toUtc;

  bool? selectedSuccess;

  int pageNumber = 1;
  int pageSize = 10;
  int totalCount = 0;
  int totalPages = 0;

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> initialize() async {
    await Future.wait([loadFilterOptions(), loadAuditLogs()]);
  }

  Future<void> loadFilterOptions() async {
    if (isLoadingFilters) {
      return;
    }

    isLoadingFilters = true;

    notifyListeners();

    try {
      final result = await repository.getFilterOptions();

      users = result.users;
      actions = result.actions;
      entityTypes = result.entityTypes;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);
    } finally {
      isLoadingFilters = false;

      notifyListeners();
    }
  }

  Future<void> loadAuditLogs({
    int? requestedPage,
    bool clearCurrentResults = false,
  }) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;

    if (clearCurrentResults) {
      logs = [];
      totalCount = 0;
      totalPages = 0;
    }

    notifyListeners();

    try {
      final result = await repository.getAuditLogs(
        pageNumber: requestedPage ?? pageNumber,
        pageSize: pageSize,
        search: search,
        adminUserId: selectedAdminUserId,
        action: selectedAction,
        entityType: selectedEntityType,
        fromUtc: fromUtc,
        toUtc: toUtc,
        isSuccessful: selectedSuccess,
      );

      logs = result.items;

      pageNumber = result.pageNumber == 0 ? 1 : result.pageNumber;

      pageSize = result.pageSize == 0 ? pageSize : result.pageSize;

      totalCount = result.totalCount;
      totalPages = result.totalPages;
    } catch (error) {
      logs = [];
      totalCount = 0;
      totalPages = 0;

      errorMessage = AppErrorHelper.message(error);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void updateSearch(String value) {
    search = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
    });
  }

  Future<void> setAdminUser(int? value) {
    selectedAdminUserId = value;

    return loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> setAction(String? value) {
    selectedAction = _normalizeText(value);

    return loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> setEntityType(String? value) {
    selectedEntityType = _normalizeText(value);

    return loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> setResult(bool? value) {
    selectedSuccess = value;

    return loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> setPeriod({DateTime? from, DateTime? to}) {
    fromUtc = from;
    toUtc = to;

    return loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> clearFilters() {
    _searchDebounce?.cancel();

    search = '';

    selectedAdminUserId = null;
    selectedAction = null;
    selectedEntityType = null;
    selectedSuccess = null;

    fromUtc = null;
    toUtc = null;

    return loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> changePageSize(int value) {
    if (pageSize == value) {
      return Future.value();
    }

    pageSize = value;

    return loadAuditLogs(requestedPage: 1, clearCurrentResults: true);
  }

  Future<void> previousPage() {
    if (!hasPreviousPage || isLoading) {
      return Future.value();
    }

    return loadAuditLogs(requestedPage: pageNumber - 1);
  }

  Future<void> nextPage() {
    if (!hasNextPage || isLoading) {
      return Future.value();
    }

    return loadAuditLogs(requestedPage: pageNumber + 1);
  }

  Future<void> refresh() {
    return loadAuditLogs(requestedPage: pageNumber);
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }

  String? _normalizeText(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
