import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/workshop_model.dart';
import '../../data/repositories/workshop_management_repository.dart';

class WorkshopManagementViewModel extends ChangeNotifier {
  final WorkshopManagementRepository repository;

  WorkshopManagementViewModel({required this.repository});

  Timer? _searchDebounce;

  bool isLoading = false;

  bool isActionLoading = false;

  String? error;

  List<WorkshopModel> workshops = [];

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String search = '';

  int? selectedType;

  int? selectedStatus;

  DateTime? fromUtc;

  DateTime? toUtc;

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> loadWorkshops({
    bool resetPage = false,
    bool clearCurrentResults = false,
  }) async {
    if (isLoading) {
      return;
    }

    if (resetPage) {
      pageNumber = 1;
    }

    isLoading = true;

    error = null;

    if (clearCurrentResults) {
      workshops = [];

      totalCount = 0;
      totalPages = 0;
    }

    notifyListeners();

    try {
      final response = await repository.getWorkshops(
        search: search,
        type: selectedType,
        status: selectedStatus,
        fromUtc: fromUtc,
        toUtc: toUtc,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      workshops = response.items;

      pageNumber = response.pageNumber == 0 ? 1 : response.pageNumber;

      pageSize = response.pageSize == 0 ? pageSize : response.pageSize;

      totalCount = response.totalCount;

      totalPages = response.totalPages;
    } catch (exception) {
      workshops = [];

      totalCount = 0;
      totalPages = 0;

      error = AppErrorHelper.message(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void updateSearch(String value) {
    search = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      loadWorkshops(resetPage: true, clearCurrentResults: true);
    });
  }

  Future<void> applyFilters() {
    _searchDebounce?.cancel();

    return loadWorkshops(resetPage: true, clearCurrentResults: true);
  }

  Future<void> changePageSize(int value) {
    if (value == pageSize) {
      return Future.value();
    }

    pageSize = value;

    return loadWorkshops(resetPage: true, clearCurrentResults: true);
  }

  Future<void> nextPage() async {
    if (!hasNextPage || isLoading) {
      return;
    }

    pageNumber++;

    await loadWorkshops();
  }

  Future<void> previousPage() async {
    if (!hasPreviousPage || isLoading) {
      return;
    }

    pageNumber--;

    await loadWorkshops();
  }

  Future<bool> deleteWorkshop(int workshopId) async {
    if (isActionLoading) {
      return false;
    }

    isActionLoading = true;

    error = null;

    notifyListeners();

    try {
      await repository.deleteWorkshop(workshopId);

      final requestedPage = workshops.length == 1 && pageNumber > 1
          ? pageNumber - 1
          : pageNumber;

      pageNumber = requestedPage;

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> cancelWorkshop({
    required int workshopId,
    required String reason,
  }) async {
    if (isActionLoading) {
      return false;
    }

    isActionLoading = true;

    error = null;

    notifyListeners();

    try {
      await repository.cancelWorkshop(
        workshopId: workshopId,
        reason: reason.trim(),
      );

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<void> clearFilters() async {
    _searchDebounce?.cancel();

    search = '';

    selectedType = null;

    selectedStatus = null;

    fromUtc = null;

    toUtc = null;

    await loadWorkshops(resetPage: true, clearCurrentResults: true);
  }

  Future<bool> deactivateWorkshop(int workshopId) async {
    if (isActionLoading) {
      return false;
    }

    isActionLoading = true;

    error = null;

    notifyListeners();

    try {
      await repository.deactivateWorkshop(workshopId);

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> activateWorkshop(int workshopId) async {
    if (isActionLoading) {
      return false;
    }

    isActionLoading = true;

    error = null;

    notifyListeners();

    try {
      await repository.activateWorkshop(workshopId);

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

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

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
