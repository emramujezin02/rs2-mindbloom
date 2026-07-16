import 'package:flutter/foundation.dart';

import '../../data/models/admin_appointment_details_model.dart';
import '../../data/repositories/appointment_management_repository.dart';

class AppointmentManagementDetailsViewModel extends ChangeNotifier {
  final AppointmentManagementRepository repository;

  AppointmentManagementDetailsViewModel({required this.repository});

  bool isLoading = false;

  bool isCancelling = false;

  String? error;

  AdminAppointmentDetailsModel? appointment;

  Future<void> load(int appointmentId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      appointment = await repository.getDetails(appointmentId);
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> cancel({
    required int appointmentId,
    required String reason,
  }) async {
    isCancelling = true;
    error = null;
    notifyListeners();

    try {
      await repository.cancelAppointment(
        appointmentId: appointmentId,
        reason: reason,
      );

      appointment = await repository.getDetails(appointmentId);

      isCancelling = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isCancelling = false;
      notifyListeners();

      return false;
    }
  }
}
