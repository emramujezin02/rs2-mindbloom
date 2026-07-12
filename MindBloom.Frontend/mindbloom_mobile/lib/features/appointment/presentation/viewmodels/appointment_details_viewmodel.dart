import 'package:flutter/foundation.dart';

import '../../data/models/appointment_model.dart';
import '../../data/repositories/appointment_repository.dart';

class AppointmentDetailsViewModel extends ChangeNotifier {
  final AppointmentRepository repository;

  AppointmentDetailsViewModel({
    required this.repository,
    required AppointmentModel appointment,
  }) : currentAppointment = appointment;

  AppointmentModel currentAppointment;

  bool isLoading = false;
  String? errorMessage;

  Future<bool> cancelAppointment(String reason) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.cancelAppointment(
        appointmentId: currentAppointment.id,
        reason: reason,
      );

      await _reloadCurrentAppointment();

      isLoading = false;
      notifyListeners();

      return true;
    } catch (error) {
      isLoading = false;
      errorMessage = error.toString();
      notifyListeners();

      return false;
    }
  }

  Future<void> _reloadCurrentAppointment() async {
    final appointments = await repository.getMyAppointments();

    for (final appointment in appointments) {
      if (appointment.id == currentAppointment.id) {
        currentAppointment = appointment;

        return;
      }
    }
  }
}
