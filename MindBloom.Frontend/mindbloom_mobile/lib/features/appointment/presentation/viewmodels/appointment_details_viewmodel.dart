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
  bool isRefreshingSession = false;
  String? errorMessage;

  Future<void> loadDetails() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentAppointment = await repository.getAppointmentDetails(
        currentAppointment.id,
      );
    } catch (error) {
      errorMessage = _friendlyError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshSessionAccess() async {
    if (isRefreshingSession) {
      return false;
    }

    isRefreshingSession = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentAppointment = await repository.getAppointmentDetails(
        currentAppointment.id,
      );

      return currentAppointment.canAccessSession &&
          currentAppointment.meetingLink != null &&
          currentAppointment.meetingLink!.trim().isNotEmpty;
    } catch (error) {
      errorMessage = _friendlyError(error);

      return false;
    } finally {
      isRefreshingSession = false;
      notifyListeners();
    }
  }

  Future<bool> cancelAppointment(String reason) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.cancelAppointment(
        appointmentId: currentAppointment.id,
        reason: reason,
      );

      currentAppointment = await repository.getAppointmentDetails(
        currentAppointment.id,
      );

      return true;
    } catch (error) {
      errorMessage = _friendlyError(error);

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();

    if (message.isEmpty) {
      return 'Appointment details could not be loaded.';
    }

    return message;
  }
}
