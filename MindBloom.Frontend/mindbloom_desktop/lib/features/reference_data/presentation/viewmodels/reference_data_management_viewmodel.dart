import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/therapist_specialization_model.dart';
import '../../data/repositories/reference_data_repository.dart';

class ReferenceDataManagementViewModel extends ChangeNotifier {
  final ReferenceDataRepository repository;

  ReferenceDataManagementViewModel({required this.repository});

  final List<TherapistSpecializationModel> specializations = [];

  bool isLoading = false;

  bool isActionLoading = false;

  String? errorMessage;

  String search = '';

  bool? activeFilter;

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  Timer? _searchDebounce;

  bool get canGoPrevious {
    return pageNumber > 1;
  }

  bool get canGoNext {
    return pageNumber < totalPages;
  }

  Future<void> loadSpecializations({int? requestedPage}) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final response = await repository.getTherapistSpecializations(
        pageNumber: requestedPage ?? pageNumber,
        pageSize: pageSize,
        search: search,
        isActive: activeFilter,
      );

      specializations
        ..clear()
        ..addAll(response.items);

      pageNumber = response.pageNumber;
      pageSize = response.pageSize;
      totalCount = response.totalCount;
      totalPages = response.totalPages;
    } catch (exception) {
      errorMessage = exception.toString();
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void updateSearch(String value) {
    search = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      loadSpecializations(requestedPage: 1);
    });
  }

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();

    search = '';

    await loadSpecializations(requestedPage: 1);
  }

  Future<void> updateActiveFilter(bool? value) async {
    activeFilter = value;

    await loadSpecializations(requestedPage: 1);
  }

  Future<void> changePageSize(int value) async {
    pageSize = value;

    await loadSpecializations(requestedPage: 1);
  }

  Future<void> previousPage() async {
    if (!canGoPrevious || isLoading) {
      return;
    }

    await loadSpecializations(requestedPage: pageNumber - 1);
  }

  Future<void> nextPage() async {
    if (!canGoNext || isLoading) {
      return;
    }

    await loadSpecializations(requestedPage: pageNumber + 1);
  }

  Future<bool> createSpecialization({
    required String name,
    String? description,
    required bool isActive,
  }) async {
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.createTherapistSpecialization(
        name: name,
        description: description,
        isActive: isActive,
      );

      await loadSpecializations(requestedPage: 1);

      return true;
    } catch (exception) {
      errorMessage = exception.toString();

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateSpecialization({
    required int id,
    required String name,
    String? description,
  }) async {
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateTherapistSpecialization(
        id: id,
        name: name,
        description: description,
      );

      await loadSpecializations(requestedPage: pageNumber);

      return true;
    } catch (exception) {
      errorMessage = exception.toString();

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateStatus({
    required TherapistSpecializationModel specialization,
    required bool isActive,
  }) async {
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateTherapistSpecializationStatus(
        id: specialization.id,
        isActive: isActive,
      );

      await loadSpecializations(requestedPage: pageNumber);

      return true;
    } catch (exception) {
      errorMessage = exception.toString();

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> deleteSpecialization(int id) async {
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.deleteTherapistSpecialization(id);

      final requestedPage = specializations.length == 1 && pageNumber > 1
          ? pageNumber - 1
          : pageNumber;

      await loadSpecializations(requestedPage: requestedPage);

      return true;
    } catch (exception) {
      errorMessage = exception.toString();

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
