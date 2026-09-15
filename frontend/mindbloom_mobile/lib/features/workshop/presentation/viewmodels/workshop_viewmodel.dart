import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/workshop_model.dart';
import '../../data/repositories/workshop_repository.dart';

class WorkshopViewModel extends ChangeNotifier {
  final WorkshopRepository repository;

  WorkshopViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingDetails = false;
  bool isSaving = false;

  String? error;
  String? loadMoreError;
  String? registrationLoadMoreError;

  List<WorkshopModel> workshops = [];
  List<WorkshopModel> myRegistrations = [];

  WorkshopModel? selectedWorkshop;

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  int registrationPageNumber = 1;
  int registrationTotalPages = 0;

  String currentSearch = '';

  bool get hasMorePages => pageNumber < totalPages;

  bool get hasMoreRegistrationPages =>
      registrationPageNumber < registrationTotalPages;

  Future<void> loadWorkshops({String search = ''}) async {
    isLoading = true;
    error = null;
    loadMoreError = null;
    pageNumber = 1;
    currentSearch = search;
    notifyListeners();

    try {
      final response = await repository.getWorkshops(
        pageNumber: 1,
        pageSize: pageSize,
        search: currentSearch,
      );

      workshops = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;

      error = null;
      loadMoreError = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreWorkshops() async {
    if (isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getWorkshops(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        search: currentSearch,
      );

      final existingIds = workshops.map((item) => item.id).toSet();

      final newItems = response.items
          .where((item) => !existingIds.contains(item.id))
          .toList();

      workshops.addAll(newItems);

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;

      loadMoreError = null;
    } catch (exception) {
      loadMoreError = AppErrorMessage.from(exception);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadMoreWorkshops() {
    return loadMoreWorkshops();
  }

  Future<void> loadWorkshopDetails(int workshopId) async {
    isLoadingDetails = true;
    error = null;
    notifyListeners();

    try {
      selectedWorkshop = await repository.getWorkshop(workshopId);

      error = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<bool> register(int workshopId) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.register(workshopId);

      selectedWorkshop = await repository.getWorkshop(workshopId);

      error = null;

      return true;
    } catch (exception) {
      error = AppErrorMessage.from(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> cancelRegistration(int workshopId) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.cancelRegistration(workshopId);

      selectedWorkshop = await repository.getWorkshop(workshopId);

      error = null;

      return true;
    } catch (exception) {
      error = AppErrorMessage.from(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadMyRegistrations() async {
    isLoading = true;
    error = null;
    registrationLoadMoreError = null;
    registrationPageNumber = 1;
    notifyListeners();

    try {
      final response = await repository.getMyRegistrations(
        pageNumber: 1,
        pageSize: pageSize,
      );

      myRegistrations = response.items;

      registrationPageNumber = response.pageNumber;

      registrationTotalPages = response.totalPages;

      error = null;
      registrationLoadMoreError = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreMyRegistrations() async {
    if (isLoadingMore || !hasMoreRegistrationPages) {
      return;
    }

    isLoadingMore = true;
    registrationLoadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getMyRegistrations(
        pageNumber: registrationPageNumber + 1,
        pageSize: pageSize,
      );

      final existingIds = myRegistrations.map((item) => item.id).toSet();

      final newItems = response.items
          .where((item) => !existingIds.contains(item.id))
          .toList();

      myRegistrations.addAll(newItems);

      registrationPageNumber = response.pageNumber;

      registrationTotalPages = response.totalPages;

      registrationLoadMoreError = null;
    } catch (exception) {
      registrationLoadMoreError = AppErrorMessage.from(exception);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadMoreMyRegistrations() {
    return loadMoreMyRegistrations();
  }

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;
    notifyListeners();
  }

  void clearLoadMoreError() {
    if (loadMoreError == null) {
      return;
    }

    loadMoreError = null;
    notifyListeners();
  }

  void clearRegistrationLoadMoreError() {
    if (registrationLoadMoreError == null) {
      return;
    }

    registrationLoadMoreError = null;
    notifyListeners();
  }
}
