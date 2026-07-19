import 'package:flutter/foundation.dart';

import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../../data/repositories/appointment_repository.dart';

class TherapistAppointmentsViewModel extends ChangeNotifier {
  final AppointmentRepository repository;

  TherapistAppointmentsViewModel({required this.repository});

  final List<AppointmentModel> _appointments = [];

  bool isLoading = false;
  bool isUpdatingStatus = false;

  int? updatingAppointmentId;

  String? errorMessage;

  TherapistAppointmentStatus? selectedFilter;

  List<AppointmentModel> get appointments {
    final sortedAppointments = [..._appointments]
      ..sort((first, second) {
        return second.startUtc.compareTo(first.startUtc);
      });

    final filter = selectedFilter;

    if (filter == null) {
      return sortedAppointments;
    }

    return sortedAppointments.where((appointment) {
      return appointment.status.trim().toLowerCase() ==
          filter.label.toLowerCase();
    }).toList();
  }

  int get totalCount => _appointments.length;

  int countByStatus(TherapistAppointmentStatus status) {
    return _appointments.where((appointment) {
      return appointment.status.trim().toLowerCase() ==
          status.label.toLowerCase();
    }).length;
  }

  Future<void> loadAppointments() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.getTherapistAppointments();

      _appointments
        ..clear()
        ..addAll(result);
    } catch (error) {
      errorMessage = _cleanError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus({
    required AppointmentModel appointment,
    required TherapistAppointmentStatus status,
  }) async {
    if (isUpdatingStatus) {
      return false;
    }

    isUpdatingStatus = true;
    updatingAppointmentId = appointment.id;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.updateTherapistAppointmentStatus(
        appointmentId: appointment.id,
        status: status,
      );

      final index = _appointments.indexWhere(
        (item) => item.id == appointment.id,
      );

      if (index != -1) {
        _appointments[index] = _appointments[index].copyWith(
          status: status.label,
        );
      }

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isUpdatingStatus = false;
      updatingAppointmentId = null;
      notifyListeners();
    }
  }

  void selectFilter(TherapistAppointmentStatus? filter) {
    if (selectedFilter == filter) {
      return;
    }

    selectedFilter = filter;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  String _cleanError(Object error) {
    final message = error.toString();

    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('AppException: ', '')
        .trim();
  }
}
