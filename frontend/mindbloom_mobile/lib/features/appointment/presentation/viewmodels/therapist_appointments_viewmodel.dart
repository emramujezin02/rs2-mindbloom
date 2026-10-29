import 'package:flutter/foundation.dart';
import '../../../../core/time/appointment_time_zone.dart';
import '../../../therapist/data/repositories/therapist_repository.dart';
import '../../data/models/booking_slot.dart';
import '../../data/models/booking_slot_generator.dart';
import '../../data/models/occupied_slot_model.dart';
import '../../data/models/unavailable_date_model.dart';

import '../../data/models/appointment_model.dart';
import '../../data/models/therapist_appointment_status.dart';
import '../../data/repositories/appointment_repository.dart';

enum TherapistAppointmentDateFilter { all, today, thisWeek, custom }

class TherapistAppointmentsViewModel extends ChangeNotifier {
  static const int pageSize = 10;

  final AppointmentRepository repository;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  TherapistAppointmentsViewModel({
    required this.repository,
    this.therapistRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TherapistRepository? therapistRepository;
  final DateTime Function() _now;
  int _request = 0;
  int? _therapistId;
  List<BookingSlot> freeSlots = [];
  DateTime get now => AppointmentTimeZone.fromInstant(_now());
  DateTime get today => DateTime.utc(now.year, now.month, now.day);
  DateTime get day => selectedDate ?? today;
  bool get isHistoricalDay => day.isBefore(today);
  bool get isDailyOverview => therapistRepository != null;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool _blocks(AppointmentModel appointment) =>
      ['pending', 'accepted'].contains(appointment.status.toLowerCase());
  List<AppointmentModel> get occupiedAppointments =>
      appointments.where(_blocks).toList();
  List<AppointmentModel> get otherAppointments =>
      appointments.where((a) => !_blocks(a)).toList();

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
    if (isDailyOverview && selectedStatusFilter != null) {
      filteredAppointments.removeWhere(
        (a) =>
            a.status.toLowerCase() != selectedStatusFilter!.label.toLowerCase(),
      );
    }

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
    if (isDailyOverview) return _loadDailyOverview();
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
    String? reason,
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
        reason: reason,
      );
      if (_disposed) return true;

      /*
       * The list is fetched again from the API after every successful
       * status change. This keeps the local state synchronized with
       * the backend state machine and any backend-side changes.
       */
      if (isDailyOverview) {
        await loadAppointments();
      } else {
        await _reloadAppointments();
      }

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isUpdatingStatus = false;
      updatingAppointmentId = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> selectStatusFilter(TherapistAppointmentStatus? filter) async {
    if (selectedStatusFilter == filter) {
      return;
    }

    selectedStatusFilter = filter;
    if (isDailyOverview) {
      notifyListeners();
      return;
    }
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
    selectedDate = DateTime.utc(date.year, date.month, date.day);
    await loadAppointments();
  }

  Future<void> clearFilters() async {
    selectedStatusFilter = null;
    if (isDailyOverview) {
      notifyListeners();
      return;
    }
    selectedDateFilter = TherapistAppointmentDateFilter.all;
    selectedDate = null;
    await loadAppointments();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _loadDailyOverview() async {
    final request = ++_request;
    final selected = day;
    selectedDate = selected;
    final (start, end) = AppointmentTimeZone.dayBounds(selected);
    isLoading = true;
    errorMessage = null;
    _appointments.clear();
    freeSlots = [];
    notifyListeners();
    try {
      _therapistId ??=
          (await therapistRepository!.getTherapistProfile()).therapistId;
      if (_disposed || request != _request) return;
      final id = _therapistId!;
      final availability = await repository.getTherapistAvailabilities(id);
      if (_disposed || request != _request) return;
      final absences = <UnavailableDateModel>[];
      var page = 1;
      while (true) {
        final response = await repository.getTherapistUnavailableDates(
          therapistId: id,
          fromUtc: start,
          toUtc: end,
          pageNumber: page++,
        );
        if (_disposed || request != _request) return;
        absences.addAll(response.items);
        if (!response.hasNextPage) break;
      }
      final all = <AppointmentModel>[];
      page = 1;
      while (true) {
        final response = await repository.getTherapistAppointments(
          pageNumber: page++,
          pageSize: 50,
          fromUtc: start,
          toUtc: end,
          overlapsRange: true,
        );
        if (_disposed || request != _request) return;
        all.addAll(response.items);
        if (!response.hasNextPage) break;
      }
      if (_disposed || request != _request) return;
      _appointments.addAll({for (final a in all) a.id: a}.values);
      if (!isHistoricalDay) {
        freeSlots = BookingSlotGenerator.generate(
          date: selected,
          dailyOccupiedSlots: all
              .where(_blocks)
              .map(
                (a) =>
                    OccupiedSlotModel(startUtc: a.startUtc, endUtc: a.endUtc),
              )
              .toList(),
          availabilities: availability,
          unavailableDates: absences,
          now: _now(),
        ).where((slot) => slot.isAvailable).toList();
      }
      pageNumber = 1;
      totalPages = 1;
    } catch (error) {
      if (_disposed || request != _request) return;
      errorMessage = _cleanError(error);
    } finally {
      if (!_disposed && request == _request) {
        isLoading = false;
        notifyListeners();
      }
    }
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

      final existingIds = _appointments
          .map((appointment) => appointment.id)
          .toSet();

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
