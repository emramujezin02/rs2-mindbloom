import 'package:flutter/material.dart';

import '../../data/models/therapist_option_model.dart';
import '../../data/models/workshop_model.dart';
import '../../data/repositories/workshop_management_repository.dart';

class WorkshopFormViewModel extends ChangeNotifier {
  final WorkshopManagementRepository repository;

  WorkshopFormViewModel({required this.repository});

  bool isLoading = false;

  bool isSaving = false;

  String? error;

  WorkshopModel? workshop;

  List<TherapistOptionModel> therapists = [];

  Future<void> initialize(int? workshopId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getTherapists(),
        if (workshopId != null) repository.getWorkshop(workshopId),
      ]);

      therapists = results.first as List<TherapistOptionModel>;

      if (workshopId != null) {
        workshop = results[1] as WorkshopModel;
      }
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> save({
    required int? workshopId,
    required String title,
    required String description,
    required DateTime startUtc,
    required DateTime endUtc,
    required int type,
    required String? onlineLink,
    required String? location,
    required int capacity,
    required double price,
    required int? therapistId,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      if (workshopId == null) {
        await repository.createWorkshop(
          title: title,
          description: description,
          startUtc: startUtc,
          endUtc: endUtc,
          type: type,
          onlineLink: onlineLink,
          location: location,
          capacity: capacity,
          price: price,
          therapistId: therapistId,
        );
      } else {
        await repository.updateWorkshop(
          workshopId: workshopId,
          title: title,
          description: description,
          startUtc: startUtc,
          endUtc: endUtc,
          type: type,
          onlineLink: onlineLink,
          location: location,
          capacity: capacity,
          price: price,
          therapistId: therapistId,
        );
      }

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
}
