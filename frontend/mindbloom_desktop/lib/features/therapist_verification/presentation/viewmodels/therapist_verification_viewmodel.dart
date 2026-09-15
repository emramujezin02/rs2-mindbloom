import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/therapist_verification_list_model.dart';
import '../../data/repositories/therapist_verification_repository.dart';

class TherapistVerificationViewModel extends ChangeNotifier {
  final TherapistVerificationRepository repository;

  TherapistVerificationViewModel({required this.repository});

  Timer? _searchDebounce;

  bool isLoading = false;

  String? errorMessage;

  List<TherapistVerificationListModel> therapists = [];

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String search = '';

  String? status = 'Pending';

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> load({
    int? page,
    String? searchValue,
    String? statusValue,
    bool changeStatus = false,
    bool clearCurrentResults = false,
  }) async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    errorMessage = null;

    if (clearCurrentResults) {
      therapists = [];

      totalCount = 0;

      totalPages = 0;
    }

    notifyListeners();

    try {
      final result = await repository.getPendingTherapists(
        pageNumber: page ?? pageNumber,
        pageSize: pageSize,
        search: search,
        status: status,
      );

      therapists = result.items;

      pageNumber = result.pageNumber == 0 ? 1 : result.pageNumber;

      pageSize = result.pageSize == 0 ? pageSize : result.pageSize;

      totalCount = result.totalCount;

      totalPages = result.totalPages;
    } catch (error) {
      therapists = [];

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
      load(page: 1, searchValue: search, clearCurrentResults: true);
    });
  }

  Future<void> filterByStatus(String? value) {
    return load(
      page: 1,
      statusValue: value,
      changeStatus: true,
      clearCurrentResults: true,
    );
  }

  Future<void> searchTherapists(String value) {
    _searchDebounce?.cancel();

    return load(page: 1, searchValue: value, clearCurrentResults: true);
  }

  Future<void> clearSearch() {
    _searchDebounce?.cancel();

    return load(page: 1, searchValue: '', clearCurrentResults: true);
  }

  Future<void> clearFilters() {
    _searchDebounce?.cancel();

    search = '';
    status = 'Pending';

    return load(
      page: 1,
      searchValue: '',
      statusValue: 'Pending',
      changeStatus: true,
      clearCurrentResults: true,
    );
  }

  Future<void> changePageSize(int value) {
    if (pageSize == value) {
      return Future.value();
    }

    pageSize = value;

    return load(page: 1, clearCurrentResults: true);
  }

  Future<void> previousPage() {
    if (!hasPreviousPage || isLoading) {
      return Future.value();
    }

    return load(page: pageNumber - 1);
  }

  Future<void> nextPage() {
    if (!hasNextPage || isLoading) {
      return Future.value();
    }

    return load(page: pageNumber + 1);
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
