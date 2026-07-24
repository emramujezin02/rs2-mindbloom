import 'package:flutter/material.dart';

import '../../../therapist/data/models/therapist_availability_model.dart';
import '../../data/models/appointment_create_request.dart';
import '../../data/models/occupied_slot_model.dart';
import '../../data/models/unavailable_date_model.dart';
import '../../data/repositories/appointment_repository.dart';

class AppointmentCreateViewModel extends ChangeNotifier {
  static const Duration appointmentDuration = Duration(hours: 1);

  final AppointmentRepository repository;

  AppointmentCreateViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingSlots = false;
  bool isLoadingPreview = false;

  String? error;

  List<TherapistAvailabilityModel> availabilities = [];

  List<UnavailableDateModel> unavailableDates = [];

  List<OccupiedSlotModel> occupiedSlots = [];

  List<DateTime> availableSlots = [];

  Map<DateTime, List<DateTime>> groupedPreviewSlots = {};

  Future<void> loadBookingData(int therapistId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.getTherapistAvailabilities(therapistId),
        repository.getTherapistUnavailableDates(therapistId),
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
          repository.getTherapistUnavailableDates(therapistId),
        ]);

        availabilities = results[0] as List<TherapistAvailabilityModel>;

        unavailableDates = results[1] as List<UnavailableDateModel>;
      }

      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);

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
    final normalizedDate = DateTime(date.year, date.month, date.day);

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    if (normalizedDate.isBefore(today)) {
      return false;
    }

    final backendDayOfWeek = _toBackendDayOfWeek(normalizedDate.weekday);

    final worksOnDay = availabilities.any(
      (availability) => availability.dayOfWeek == backendDayOfWeek,
    );

    if (!worksOnDay) {
      return false;
    }

    final dayStart = normalizedDate;

    final dayEnd = normalizedDate.add(const Duration(days: 1));

    final blocked = unavailableDates.any((unavailableDate) {
      final unavailableStart = unavailableDate.startUtc.toLocal();

      final unavailableEnd = unavailableDate.endUtc.toLocal();

      return unavailableStart.isBefore(dayEnd) &&
          unavailableEnd.isAfter(dayStart);
    });

    return !blocked;
  }

  Future<void> loadAvailableSlots({
    required int therapistId,
    required DateTime date,
  }) async {
    isLoadingSlots = true;
    error = null;
    occupiedSlots = [];
    availableSlots = [];
    notifyListeners();

    try {
      occupiedSlots = await repository.getOccupiedSlots(
        therapistId: therapistId,
        date: date,
      );

      availableSlots = _buildAvailableSlotsForDate(
        date: date,
        dailyOccupiedSlots: occupiedSlots,
      );
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingSlots = false;
    notifyListeners();
  }

  List<DateTime> _buildAvailableSlotsForDate({
    required DateTime date,
    required List<OccupiedSlotModel> dailyOccupiedSlots,
  }) {
    final backendDayOfWeek = _toBackendDayOfWeek(date.weekday);

    final dailyAvailabilities = availabilities
        .where((availability) => availability.dayOfWeek == backendDayOfWeek)
        .toList();

    final slots = <DateTime>[];

    for (final availability in dailyAvailabilities) {
      final startParts = _parseTime(availability.startTime);

      final endParts = _parseTime(availability.endTime);

      if (startParts == null || endParts == null) {
        continue;
      }

      var slotStart = DateTime(
        date.year,
        date.month,
        date.day,
        startParts.$1,
        startParts.$2,
      );

      final availabilityEnd = DateTime(
        date.year,
        date.month,
        date.day,
        endParts.$1,
        endParts.$2,
      );

      while (slotStart.add(appointmentDuration).compareTo(availabilityEnd) <=
          0) {
        final slotEnd = slotStart.add(appointmentDuration);

        final isPast = slotStart.isBefore(DateTime.now());

        final isOccupied = dailyOccupiedSlots.any((occupiedSlot) {
          final occupiedStart = occupiedSlot.startUtc.toLocal();

          final occupiedEnd = occupiedSlot.endUtc.toLocal();

          return slotStart.isBefore(occupiedEnd) &&
              slotEnd.isAfter(occupiedStart);
        });

        final isUnavailable = unavailableDates.any((unavailableDate) {
          final unavailableStart = unavailableDate.startUtc.toLocal();

          final unavailableEnd = unavailableDate.endUtc.toLocal();

          return slotStart.isBefore(unavailableEnd) &&
              slotEnd.isAfter(unavailableStart);
        });

        if (!isPast && !isOccupied && !isUnavailable) {
          slots.add(slotStart);
        }

        slotStart = slotStart.add(appointmentDuration);
      }
    }

    slots.sort();

    return slots;
  }

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
  notifyListeners();

  try {
    await repository.createAppointment(
      AppointmentCreateRequest(
        therapistId: therapistId,
        startUtc: startUtc,
        endUtc: endUtc,
        type: type,
        meetingLink: meetingLink,
        location: location,
        notes: notes,
      ),
    );

    isLoading = false;
    notifyListeners();

    return true;
  } catch (exception) {
    error = exception.toString();
    isLoading = false;
    notifyListeners();

    return false;
  }
}

  static int _toBackendDayOfWeek(int dartWeekday) {
    return dartWeekday == DateTime.sunday ? 0 : dartWeekday;
  }

  static (int, int)? _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return (hour, minute);
  }
}
