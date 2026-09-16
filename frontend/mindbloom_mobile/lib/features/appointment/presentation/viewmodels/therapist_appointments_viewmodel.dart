import 'package:flutter/foundation.dart';

import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../../data/repositories/appointment_repository.dart';

enum TherapistAppointmentDateFilter { all, today, thisWeek, custom }

class TherapistAppointmentsViewModel extends ChangeNotifier {
  static const int pageSize = 10;

  final AppointmentRepository repository;

  TherapistAppointmentsViewModel({required this.repository});

  final List<AppointmentModel> _appointments = [];

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isUpdatingStatus = false;

  int? updatingAppointmentId;

  String? errorMessage;
  String? loadMoreErrorMessage;

  TherapistAppointmentStatus? selectedStatusFilter;

  TherapistAppointmentDateFilter selectedDateFilter =
      TherapistAppointmentDateFilter.all;

  DateTime? selectedDate;

  int pageNumber = 1;
  int totalPages = 0;

  bool get hasMorePages => pageNumber < totalPages;

  List<AppointmentModel> get appointments {
    final filteredAppointments = _appointments.toList();

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

  Future<void> selectStatusFilter(TherapistAppointmentStatus? filter) async {
    if (selectedStatusFilter == filter) {
      return;
    }

    selectedStatusFilter = filter;
    await loadAppointments();
  }

  Future<void> selectAllDates() async {
    selectedDateFilter = TherapistAppointmentDateFilter.all;
    selectedDate = null;
    await loadAppointments();
  }

  Future<void> selectToday() async {
    selectedDateFilter = TherapistAppointmentDateFilter.today;
    selectedDate = null;
    await loadAppointments();
  }

  Future<void> selectThisWeek() async {
    selectedDateFilter = TherapistAppointmentDateFilter.thisWeek;
    selectedDate = null;
    await loadAppointments();
  }

  Future<void> selectCustomDate(DateTime date) async {
    selectedDateFilter = TherapistAppointmentDateFilter.custom;
    selectedDate = DateTime(date.year, date.month, date.day);
    await loadAppointments();
  }

  Future<void> clearFilters() async {
    selectedStatusFilter = null;
    selectedDateFilter = TherapistAppointmentDateFilter.all;
    selectedDate = null;
    await loadAppointments();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _reloadAppointments() async {
    loadMoreErrorMessage = null;
    pageNumber = 1;

    final result = await repository.getTherapistAppointments(
      pageNumber: 1,
      pageSize: pageSize,
      status: selectedStatusFilter?.label,
      fromUtc: _dateRange?.$1,
      toUtc: _dateRange?.$2,
    );

    _appointments
      ..clear()
      ..addAll(result.items);

    pageNumber = result.pageNumber;
    totalPages = result.totalPages;
  }

  Future<void> loadMoreAppointments() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final result = await repository.getTherapistAppointments(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        status: selectedStatusFilter?.label,
        fromUtc: _dateRange?.$1,
        toUtc: _dateRange?.$2,
      );

      final existingIds =
          _appointments.map((appointment) => appointment.id).toSet();

      _appointments.addAll(
        result.items.where(
          (appointment) => !existingIds.contains(appointment.id),
        ),
      );

      pageNumber = result.pageNumber;
      totalPages = result.totalPages;
    } catch (error) {
      loadMoreErrorMessage = _cleanError(error);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  (DateTime, DateTime)? get _dateRange {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (selectedDateFilter) {
      case TherapistAppointmentDateFilter.all:
        return null;

      case TherapistAppointmentDateFilter.today:
        final start = today.toUtc();
        return (start, start.add(const Duration(days: 1)));

      case TherapistAppointmentDateFilter.thisWeek:
        final startOfWeek = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );

        final start = startOfWeek.toUtc();
        return (start, start.add(const Duration(days: 7)));

      case TherapistAppointmentDateFilter.custom:
        final date = selectedDate;

        if (date == null) {
          return null;
        }

        final start = DateTime(date.year, date.month, date.day).toUtc();
        return (start, start.add(const Duration(days: 1)));
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
