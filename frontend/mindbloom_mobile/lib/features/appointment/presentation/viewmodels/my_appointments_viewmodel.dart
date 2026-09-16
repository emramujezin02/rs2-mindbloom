import 'package:flutter/material.dart';

import '../../data/models/appointment_model.dart';
import '../../data/repositories/appointment_repository.dart';

class MyAppointmentsViewModel extends ChangeNotifier {
  static const int pageSize = 10;

  final AppointmentRepository repository;

  MyAppointmentsViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  String? error;
  String? loadMoreError;

  List<AppointmentModel> appointments = [];

  String? selectedStatus;
  DateTime? selectedDate;

  int pageNumber = 1;
  int totalPages = 0;

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadAppointments() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    loadMoreError = null;
    pageNumber = 1;
    notifyListeners();

    try {
      final response = await repository.getMyAppointments(
        pageNumber: 1,
        pageSize: pageSize,
        status: selectedStatus,
        fromUtc: _selectedDateStartUtc,
        toUtc: _selectedDateEndUtc,
      );

      appointments = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      appointments.sort(
        (first, second) => first.startUtc.compareTo(second.startUtc),
      );
    } catch (exception) {
      error = _friendlyError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreAppointments() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getMyAppointments(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        status: selectedStatus,
        fromUtc: _selectedDateStartUtc,
        toUtc: _selectedDateEndUtc,
      );

      final existingIds =
          appointments.map((appointment) => appointment.id).toSet();

      appointments.addAll(
        response.items.where(
          (appointment) => !existingIds.contains(appointment.id),
        ),
      );

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      appointments.sort(
        (first, second) => first.startUtc.compareTo(second.startUtc),
      );
    } catch (exception) {
      loadMoreError = _friendlyError(exception);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  List<String> get statusOptions {
    return const ['Pending', 'Accepted', 'Rejected', 'Completed', 'Cancelled'];
  }

  List<AppointmentModel> get filteredAppointments {
    return appointments;
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
    return upcomingAppointments;
  }

  List<AppointmentModel> get visiblePastAppointments {
    return pastAppointments;
  }

  bool get hasMoreUpcoming {
    return false;
  }

  bool get hasMorePast {
    return false;
  }

  bool get hasActiveFilters {
    return selectedStatus != null || selectedDate != null;
  }

  bool get filteredListIsEmpty {
    return upcomingAppointments.isEmpty && pastAppointments.isEmpty;
  }

  Future<void> setStatusFilter(String? status) async {
    selectedStatus = status;
    await loadAppointments();
  }

  Future<void> setDateFilter(DateTime? date) async {
    selectedDate = date == null
        ? null
        : DateTime(date.year, date.month, date.day);

    await loadAppointments();
  }

  Future<void> clearFilters() async {
    selectedStatus = null;
    selectedDate = null;
    await loadAppointments();
  }

  Future<void> loadMoreUpcoming() {
    return loadMoreAppointments();
  }

  Future<void> loadMorePast() {
    return loadMoreAppointments();
  }

  DateTime? get _selectedDateStartUtc {
    final date = selectedDate;

    if (date == null) {
      return null;
    }

    return DateTime(date.year, date.month, date.day).toUtc();
  }

  DateTime? get _selectedDateEndUtc {
    final start = _selectedDateStartUtc;

    return start?.add(const Duration(days: 1));
  }

  String _friendlyError(Object exception) {
    final message = exception.toString().replaceFirst('Exception: ', '').trim();

    if (message.isEmpty) {
      return 'Appointments could not be loaded.';
    }

    return message;
  }
}
