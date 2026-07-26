import 'package:flutter/foundation.dart';
import '../../../../core/error/app_exception.dart';
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

  Map<String, List<String>> fieldErrors = {};

  String? fieldError(String fieldName) {
    final requested = _normalizeFieldName(fieldName);

    for (final entry in fieldErrors.entries) {
      if (_normalizeFieldName(entry.key) == requested &&
          entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }

    return null;
  }

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
    fieldErrors = {};

    notifyListeners();

    try {
      await repository.cancelAppointment(
        appointmentId: currentAppointment.id,
        reason: reason.trim(),
      );

      currentAppointment = await repository.getAppointmentDetails(
        currentAppointment.id,
      );

      return true;
    } catch (error) {
      _setError(error, fallback: 'Termin nije moguće otkazati.');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    if (error is AppException) {
      return error.message;
    }

    final message = error.toString().replaceFirst('Exception: ', '').trim();

    if (message.isEmpty) {
      return 'Detalje termina nije moguće učitati.';
    }

    return message;
  }

  void _setError(Object exception, {required String fallback}) {
    if (exception is AppException) {
      errorMessage = exception.message.trim().isEmpty
          ? fallback
          : exception.message.trim();

      fieldErrors = Map<String, List<String>>.from(exception.fieldErrors);

      return;
    }

    final message = exception.toString().replaceFirst('Exception: ', '').trim();

    errorMessage = message.isEmpty ? fallback : message;
  }

  String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}
