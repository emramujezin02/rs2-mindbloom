import 'package:flutter/material.dart';

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
    pageNumber = 1;
    currentSearch = search;
    notifyListeners();

    try {
      final response = await repository.getWorkshops(
        pageNumber: pageNumber,
        pageSize: pageSize,
        search: currentSearch,
      );

      workshops = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreWorkshops() async {
    if (isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final response = await repository.getWorkshops(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        search: currentSearch,
      );

      workshops.addAll(response.items);

      pageNumber = response.pageNumber;

      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadWorkshopDetails(int workshopId) async {
    isLoadingDetails = true;
    error = null;
    notifyListeners();

    try {
      selectedWorkshop = await repository.getWorkshop(workshopId);
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingDetails = false;
    notifyListeners();
  }

  Future<bool> register(int workshopId) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.register(workshopId);

      await loadWorkshopDetails(workshopId);

      isSaving = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isSaving = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> cancelRegistration(int workshopId) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.cancelRegistration(workshopId);

      await loadWorkshopDetails(workshopId);

      isSaving = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isSaving = false;
      notifyListeners();

      return false;
    }
  }

  Future<void> loadMyRegistrations() async {
    isLoading = true;
    error = null;
    registrationPageNumber = 1;
    notifyListeners();

    try {
      final response = await repository.getMyRegistrations(
        pageNumber: registrationPageNumber,
        pageSize: pageSize,
      );

      myRegistrations = response.items;

      registrationPageNumber = response.pageNumber;

      registrationTotalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreMyRegistrations() async {
    if (isLoadingMore || !hasMoreRegistrationPages) {
      return;
    }

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final response = await repository.getMyRegistrations(
        pageNumber: registrationPageNumber + 1,
        pageSize: pageSize,
      );

      myRegistrations.addAll(response.items);

      registrationPageNumber = response.pageNumber;

      registrationTotalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingMore = false;
    notifyListeners();
  }
}
