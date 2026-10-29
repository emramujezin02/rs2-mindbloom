import '../../../../core/time/appointment_time_zone.dart';
import 'package:flutter/material.dart';
import '../../../../core/error/app_exception.dart';
import '../../../therapist/data/models/therapist_availability_model.dart';
import '../../data/models/appointment_create_request.dart';
import '../../data/models/booking_slot.dart';
import '../../data/models/booking_slot_generator.dart';
import '../../data/models/occupied_slot_model.dart';
import '../../data/models/unavailable_date_model.dart';
import '../../data/repositories/appointment_repository.dart';

class AppointmentCreateViewModel extends ChangeNotifier {
  static const Duration appointmentDuration =
      BookingSlotGenerator.appointmentDuration;

  final AppointmentRepository repository;

  AppointmentCreateViewModel({
    required this.repository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime get now => AppointmentTimeZone.fromInstant(_now());
  DateTime get today => DateTime.utc(now.year, now.month, now.day);
  DateTime get lastBookingDate => today.add(const Duration(days: 365));
  int? errorStatusCode;
  int _slotsRequest = 0;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _slotsRequest++;
    super.dispose();
  }

  bool isLoading = false;
  bool isLoadingSlots = false;
  bool isLoadingPreview = false;

  String? error;

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

  List<TherapistAvailabilityModel> availabilities = [];

  List<UnavailableDateModel> unavailableDates = [];

  List<OccupiedSlotModel> occupiedSlots = [];

  List<DateTime> availableSlots = [];
  List<BookingSlot> bookingSlots = [];

  Map<DateTime, List<DateTime>> groupedPreviewSlots = {};

  Future<void> loadBookingData(int therapistId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getTherapistAvailabilities(therapistId),
        _loadUnavailableDates(therapistId),
      ]);

      availabilities = results[0] as List<TherapistAvailabilityModel>;

      unavailableDates = results[1] as List<UnavailableDateModel>;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadNextAvailableSlots({
    required int therapistId,
    int daysAhead = 14,
    int maximumSlots = 8,
  }) async {
    isLoadingPreview = true;
    error = null;
    groupedPreviewSlots = {};
    notifyListeners();

    try {
      if (availabilities.isEmpty) {
        final results = await Future.wait([
          repository.getTherapistAvailabilities(therapistId),
          _loadUnavailableDates(therapistId, daysAhead: daysAhead),
        ]);

        availabilities = results[0] as List<TherapistAvailabilityModel>;

        unavailableDates = results[1] as List<UnavailableDateModel>;
      }

      final now = AppointmentTimeZone.fromInstant(_now());

      final today = DateTime.utc(now.year, now.month, now.day);

      final previewResult = <DateTime, List<DateTime>>{};

      var totalSlots = 0;

      for (var dayOffset = 0; dayOffset < daysAhead; dayOffset++) {
        if (totalSlots >= maximumSlots) {
          break;
        }

        final date = today.add(Duration(days: dayOffset));

        if (!isDateSelectable(date)) {
          continue;
        }

        final dailyOccupiedSlots = await repository.getOccupiedSlots(
          therapistId: therapistId,
          date: date,
        );

        final dailySlots = _buildAvailableSlotsForDate(
          date: date,
          dailyOccupiedSlots: dailyOccupiedSlots,
        );

        if (dailySlots.isEmpty) {
          continue;
        }

        final remainingSlots = maximumSlots - totalSlots;

        final slotsForPreview = dailySlots.take(remainingSlots).toList();

        previewResult[date] = slotsForPreview;

        totalSlots += slotsForPreview.length;
      }

      groupedPreviewSlots = previewResult;
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingPreview = false;
    notifyListeners();
  }

  bool isDateSelectable(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    if (day.isBefore(today) || day.isAfter(lastBookingDate)) return false;
    return _buildAvailableSlotsForDate(
      date: date,
      dailyOccupiedSlots: [],
    ).isNotEmpty;
  }

  Future<void> loadAvailableSlots({
    required int therapistId,
    required DateTime date,
  }) async {
    final request = ++_slotsRequest;
    isLoadingSlots = true;
    error = null;
    errorStatusCode = null;
    occupiedSlots = [];
    availableSlots = [];
    bookingSlots = [];
    notifyListeners();

    try {
      final occupied = await repository.getOccupiedSlots(
        therapistId: therapistId,
        date: date,
      );

      if (_disposed || request != _slotsRequest) return;
      occupiedSlots = occupied;
      bookingSlots = _buildSlotsForDate(
        date: date,
        dailyOccupiedSlots: occupiedSlots,
      );
      availableSlots = bookingSlots
          .where((slot) => slot.isAvailable)
          .map((slot) => slot.start)
          .toList();
    } catch (exception) {
      if (_disposed || request != _slotsRequest) return;
      _setError(exception, fallback: 'Termine nije moguće učitati.');
    }

    isLoadingSlots = false;
    notifyListeners();
  }

  List<DateTime> _buildAvailableSlotsForDate({
    required DateTime date,
    required List<OccupiedSlotModel> dailyOccupiedSlots,
  }) => _buildSlotsForDate(
    date: date,
    dailyOccupiedSlots: dailyOccupiedSlots,
  ).where((slot) => slot.isAvailable).map((slot) => slot.start).toList();

  List<BookingSlot> _buildSlotsForDate({
    required DateTime date,
    required List<OccupiedSlotModel> dailyOccupiedSlots,
  }) => BookingSlotGenerator.generate(
    date: date,
    dailyOccupiedSlots: dailyOccupiedSlots,
    availabilities: availabilities,
    unavailableDates: unavailableDates,
    now: _now(),
  );

  Future<bool> createAppointment({
    required int therapistId,
    required DateTime startUtc,
    required DateTime endUtc,
    required int type,
    String? meetingLink,
    String? location,
    String? notes,
  }) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;
    error = null;
    fieldErrors = {};
    errorStatusCode = null;

    notifyListeners();

    try {
      await repository.createAppointment(
        AppointmentCreateRequest(
          therapistId: therapistId,
          startUtc: startUtc,
          endUtc: endUtc,
          type: type,
          meetingLink: meetingLink?.trim(),
          location: location?.trim(),
          notes: notes?.trim(),
        ),
      );

      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Termin nije moguće kreirati.');

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<UnavailableDateModel>> _loadUnavailableDates(
    int therapistId, {
    int daysAhead = 370,
  }) async {
    final now = AppointmentTimeZone.fromInstant(_now());
    final rangeStart = AppointmentTimeZone.uniqueLocal(
      DateTime.utc(now.year, now.month, now.day),
    )!.toUtc();
    final rangeEnd = AppointmentTimeZone.uniqueLocal(
      DateTime.utc(now.year, now.month, now.day + daysAhead),
    )!.toUtc();

    final result = <UnavailableDateModel>[];
    var page = 1;
    while (true) {
      final response = await repository.getTherapistUnavailableDates(
        therapistId: therapistId,
        fromUtc: rangeStart,
        toUtc: rangeEnd,
        pageNumber: page,
      );
      result.addAll(response.items);
      if (!response.hasNextPage) return result;
      page++;
    }
  }

  void _setError(Object exception, {required String fallback}) {
    if (exception is AppException) {
      errorStatusCode = exception.statusCode;
      error = exception.message.trim().isEmpty
          ? fallback
          : exception.message.trim();

      fieldErrors = Map<String, List<String>>.from(exception.fieldErrors);

      return;
    }

    final message = exception.toString().replaceFirst('Exception: ', '').trim();

    error = message.isEmpty ? fallback : message;
  }

  String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}
