import 'package:flutter/material.dart';

import '../../data/models/appointment_create_request.dart';
import '../../data/repositories/appointment_repository.dart';

class AppointmentCreateViewModel extends ChangeNotifier {
  final AppointmentRepository repository;

  AppointmentCreateViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  Future<bool> createAppointment({
    required int therapistId,
    required DateTime dateTime,
    required String type,
    String? notes,
  }) async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      await repository.createAppointment(
        AppointmentCreateRequest(
          therapistId: therapistId,
          startTimeUtc: dateTime,
          type: type,
          notes: notes,
        ),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      error = e.toString();

      isLoading = false;
      notifyListeners();

      return false;
    }
  }
}
