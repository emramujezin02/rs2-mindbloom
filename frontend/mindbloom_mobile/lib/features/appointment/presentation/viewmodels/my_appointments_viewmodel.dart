import 'package:flutter/material.dart';

import '../../data/models/appointment_model.dart';
import '../../data/repositories/appointment_repository.dart';

class MyAppointmentsViewModel extends ChangeNotifier {
  static const int pageSize = 5;

  final AppointmentRepository repository;

  MyAppointmentsViewModel({required this.repository});

  bool isLoading = false;
  String? error;

  List<AppointmentModel> appointments = [];

  String? selectedStatus;
  DateTime? selectedDate;

  int _visibleUpcomingCount = pageSize;
  int _visiblePastCount = pageSize;

  Future<void> loadAppointments() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      appointments = await repository.getMyAppointments();

      appointments.sort(
        (first, second) => first.startUtc.compareTo(second.startUtc),
      );

      _resetVisibleCounts();
    } catch (exception) {
      error = _friendlyError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<String> get statusOptions {
    final statuses = appointments
        .map((appointment) => appointment.status.trim())
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList();

    statuses.sort();

    return statuses;
  }

  List<AppointmentModel> get filteredAppointments {
    return appointments.where((appointment) {
      if (selectedStatus != null &&
          appointment.status.trim().toLowerCase() !=
              selectedStatus!.trim().toLowerCase()) {
        return false;
      }

      if (selectedDate != null) {
        final localStart = appointment.startUtc.toLocal();

        if (!_isSameDate(localStart, selectedDate!)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<AppointmentModel> get upcomingAppointments {
    final result = filteredAppointments
        .where((appointment) => appointment.isUpcoming)
        .toList();

    result.sort((first, second) => first.startUtc.compareTo(second.startUtc));

    return result;
  }

  List<AppointmentModel> get pastAppointments {
    final result = filteredAppointments
        .where((appointment) => !appointment.isUpcoming)
        .toList();

    result.sort((first, second) => second.startUtc.compareTo(first.startUtc));

    return result;
  }

  List<AppointmentModel> get visibleUpcomingAppointments {
    return upcomingAppointments.take(_visibleUpcomingCount).toList();
  }

  List<AppointmentModel> get visiblePastAppointments {
    return pastAppointments.take(_visiblePastCount).toList();
  }

  bool get hasMoreUpcoming {
    return _visibleUpcomingCount < upcomingAppointments.length;
  }

  bool get hasMorePast {
    return _visiblePastCount < pastAppointments.length;
  }

  bool get hasActiveFilters {
    return selectedStatus != null || selectedDate != null;
  }

  bool get filteredListIsEmpty {
    return upcomingAppointments.isEmpty && pastAppointments.isEmpty;
  }

  void setStatusFilter(String? status) {
    selectedStatus = status;
    _resetVisibleCounts();
    notifyListeners();
  }

  void setDateFilter(DateTime? date) {
    selectedDate = date == null
        ? null
        : DateTime(date.year, date.month, date.day);

    _resetVisibleCounts();
    notifyListeners();
  }

  void clearFilters() {
    selectedStatus = null;
    selectedDate = null;
    _resetVisibleCounts();
    notifyListeners();
  }

  void loadMoreUpcoming() {
    _visibleUpcomingCount += pageSize;
    notifyListeners();
  }

  void loadMorePast() {
    _visiblePastCount += pageSize;
    notifyListeners();
  }

  void _resetVisibleCounts() {
    _visibleUpcomingCount = pageSize;
    _visiblePastCount = pageSize;
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _friendlyError(Object exception) {
    final message = exception.toString().replaceFirst('Exception: ', '').trim();

    if (message.isEmpty) {
      return 'Appointments could not be loaded.';
    }

    return message;
  }
}
