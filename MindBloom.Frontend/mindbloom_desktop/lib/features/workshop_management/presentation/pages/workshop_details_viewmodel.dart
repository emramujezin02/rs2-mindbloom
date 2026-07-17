import 'package:flutter/material.dart';

import '../../data/models/workshop_model.dart';
import '../../data/models/workshop_registration_model.dart';
import '../../data/models/workshop_registration_paged_response.dart';
import '../../data/repositories/workshop_management_repository.dart';

class WorkshopDetailsViewModel extends ChangeNotifier {
  final WorkshopManagementRepository repository;

  WorkshopDetailsViewModel({required this.repository});

  bool isLoading = false;

  bool isProcessing = false;

  String? error;

  WorkshopModel? workshop;

  List<WorkshopRegistrationModel> registrations = [];

  int registrationPageNumber = 1;

  int registrationPageSize = 10;

  int registrationTotalPages = 0;

  int registrationTotalCount = 0;

  Future<void> load(int workshopId) async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        repository.getWorkshop(workshopId),
        repository.getRegistrations(
          workshopId: workshopId,
          pageNumber: registrationPageNumber,
          pageSize: registrationPageSize,
        ),
      ]);

      workshop = results[0] as WorkshopModel;

      final registrationResponse =
          results[1] as WorkshopRegistrationPagedResponse;

      registrations = registrationResponse.items;

      registrationPageNumber = registrationResponse.pageNumber;

      registrationPageSize = registrationResponse.pageSize;

      registrationTotalPages = registrationResponse.totalPages;

      registrationTotalCount = registrationResponse.totalCount;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;

    notifyListeners();
  }

  Future<void> refresh(int workshopId) async {
    registrationPageNumber = 1;

    await load(workshopId);
  }

  Future<void> nextRegistrationsPage(int workshopId) async {
    if (registrationPageNumber >= registrationTotalPages) {
      return;
    }

    registrationPageNumber++;

    await _loadRegistrations(workshopId);
  }

  Future<void> previousRegistrationsPage(int workshopId) async {
    if (registrationPageNumber <= 1) {
      return;
    }

    registrationPageNumber--;

    await _loadRegistrations(workshopId);
  }

  Future<void> _loadRegistrations(int workshopId) async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      final response = await repository.getRegistrations(
        workshopId: workshopId,
        pageNumber: registrationPageNumber,
        pageSize: registrationPageSize,
      );

      registrations = response.items;

      registrationPageNumber = response.pageNumber;

      registrationPageSize = response.pageSize;

      registrationTotalPages = response.totalPages;

      registrationTotalCount = response.totalCount;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;

    notifyListeners();
  }

  Future<bool> cancel({required int workshopId, required String reason}) async {
    isProcessing = true;
    error = null;

    notifyListeners();

    try {
      workshop = await repository.cancelWorkshop(
        workshopId: workshopId,
        reason: reason,
      );

      isProcessing = false;

      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();

      isProcessing = false;

      notifyListeners();

      return false;
    }
  }

  Future<bool> delete(int workshopId) async {
    isProcessing = true;
    error = null;

    notifyListeners();

    try {
      await repository.deleteWorkshop(workshopId);

      isProcessing = false;

      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();

      isProcessing = false;

      notifyListeners();

      return false;
    }
  }
}
