import 'package:flutter/material.dart';

import '../../data/models/workshop_model.dart';
import '../../data/repositories/workshop_management_repository.dart';

class WorkshopManagementViewModel extends ChangeNotifier {
  final WorkshopManagementRepository repository;

  WorkshopManagementViewModel({required this.repository});

  bool isLoading = false;

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

  Future<void> loadWorkshops({bool resetPage = false}) async {
    if (resetPage) {
      pageNumber = 1;
    }

    isLoading = true;
    error = null;
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
      pageNumber = response.pageNumber;
      pageSize = response.pageSize;
      totalCount = response.totalCount;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> nextPage() async {
    if (pageNumber >= totalPages) {
      return;
    }

    pageNumber++;

    await loadWorkshops();
  }

  Future<void> previousPage() async {
    if (pageNumber <= 1) {
      return;
    }

    pageNumber--;

    await loadWorkshops();
  }

  Future<bool> deleteWorkshop(int workshopId) async {
    error = null;

    try {
      await repository.deleteWorkshop(workshopId);

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();

      return false;
    }
  }

  Future<bool> cancelWorkshop({
    required int workshopId,
    required String reason,
  }) async {
    error = null;

    try {
      await repository.cancelWorkshop(workshopId: workshopId, reason: reason);

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();

      return false;
    }
  }

  void clearFilters() {
    search = '';
    selectedType = null;
    selectedStatus = null;
    fromUtc = null;
    toUtc = null;
  }

  Future<bool> deactivateWorkshop(int workshopId) async {
    error = null;

    try {
      await repository.deactivateWorkshop(workshopId);

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = exception.toString();

      notifyListeners();

      return false;
    }
  }

  Future<bool> activateWorkshop(int workshopId) async {
    error = null;

    try {
      await repository.activateWorkshop(workshopId);

      await loadWorkshops();

      return true;
    } catch (exception) {
      error = exception.toString();

      notifyListeners();

      return false;
    }
  }
}
