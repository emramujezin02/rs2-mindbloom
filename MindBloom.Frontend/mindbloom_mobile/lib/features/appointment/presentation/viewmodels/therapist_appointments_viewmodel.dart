import 'package:flutter/foundation.dart';

import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../../data/repositories/appointment_repository.dart';

enum TherapistAppointmentDateFilter { all, today, thisWeek, custom }

class TherapistAppointmentsViewModel extends ChangeNotifier {
  final AppointmentRepository repository;

  TherapistAppointmentsViewModel({required this.repository});

  final List<AppointmentModel> _appointments = [];

  bool isLoading = false;
  bool isUpdatingStatus = false;

  int? updatingAppointmentId;

  String? errorMessage;

  TherapistAppointmentStatus? selectedStatusFilter;

  TherapistAppointmentDateFilter selectedDateFilter =
      TherapistAppointmentDateFilter.all;

  DateTime? selectedDate;

  List<AppointmentModel> get appointments {
    final filteredAppointments = _appointments.where((appointment) {
      return _matchesStatusFilter(appointment) &&
          _matchesDateFilter(appointment);
    }).toList();

    filteredAppointments.sort((first, second) {
      return second.startUtc.compareTo(first.startUtc);
    });

    return filteredAppointments;
  }

  int get totalCount => _appointments.length;

  bool get hasActiveFilters {
    return selectedStatusFilter != null ||
        selectedDateFilter != TherapistAppointmentDateFilter.all;
  }

  int countByStatus(TherapistAppointmentStatus status) {
    return _appointments.where((appointment) {
      return appointment.status.trim().toLowerCase() ==
          status.label.toLowerCase();
    }).length;
  }

  Future<void> loadAppointments() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _reloadAppointments();
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

      /*
       * The list is fetched again from the API after every successful
       * status change. This keeps the local state synchronized with
       * the backend state machine and any backend-side changes.
       */
      await _reloadAppointments();

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

  void selectStatusFilter(TherapistAppointmentStatus? filter) {
    if (selectedStatusFilter == filter) {
      return;
    }

    selectedStatusFilter = filter;
    notifyListeners();
  }

  void selectAllDates() {
    selectedDateFilter = TherapistAppointmentDateFilter.all;
    selectedDate = null;
    notifyListeners();
  }

  void selectToday() {
    selectedDateFilter = TherapistAppointmentDateFilter.today;
    selectedDate = null;
    notifyListeners();
  }

  void selectThisWeek() {
    selectedDateFilter = TherapistAppointmentDateFilter.thisWeek;
    selectedDate = null;
    notifyListeners();
  }

  void selectCustomDate(DateTime date) {
    selectedDateFilter = TherapistAppointmentDateFilter.custom;
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void clearFilters() {
    selectedStatusFilter = null;
    selectedDateFilter = TherapistAppointmentDateFilter.all;
    selectedDate = null;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _reloadAppointments() async {
    final result = await repository.getTherapistAppointments();

    _appointments
      ..clear()
      ..addAll(result);
  }

  bool _matchesStatusFilter(AppointmentModel appointment) {
    final filter = selectedStatusFilter;

    if (filter == null) {
      return true;
    }

    return appointment.status.trim().toLowerCase() ==
        filter.label.toLowerCase();
  }

  bool _matchesDateFilter(AppointmentModel appointment) {
    final appointmentDate = appointment.startUtc.toLocal();

    final normalizedAppointmentDate = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (selectedDateFilter) {
      case TherapistAppointmentDateFilter.all:
        return true;

      case TherapistAppointmentDateFilter.today:
        return normalizedAppointmentDate == today;

      case TherapistAppointmentDateFilter.thisWeek:
        final startOfWeek = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );

        final endOfWeek = startOfWeek.add(const Duration(days: 7));

        return !normalizedAppointmentDate.isBefore(startOfWeek) &&
            normalizedAppointmentDate.isBefore(endOfWeek);

      case TherapistAppointmentDateFilter.custom:
        final date = selectedDate;

        if (date == null) {
          return true;
        }

        return normalizedAppointmentDate ==
            DateTime(date.year, date.month, date.day);
    }
  }

  String _cleanError(Object error) {
    final message = error.toString();

    return message
        .replaceFirst('Exception: ', '')
        .replaceFirst('AppException: ', '')
        .trim();
  }
}
