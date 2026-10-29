import '../../../../core/time/appointment_time_zone.dart';
import '../../../therapist/data/models/therapist_availability_model.dart';
import 'booking_slot.dart';
import 'occupied_slot_model.dart';
import 'unavailable_date_model.dart';

/// Shared Sarajevo working-hour, absence, occupancy and DST rules.
abstract final class BookingSlotGenerator {
  static const appointmentDuration = Duration(hours: 1);
  static List<BookingSlot> generate({
    required DateTime date,
    required List<OccupiedSlotModel> dailyOccupiedSlots,
    required List<TherapistAvailabilityModel> availabilities,
    required List<UnavailableDateModel> unavailableDates,
    required DateTime now,
  }) {
    final backendDayOfWeek = date.weekday % 7;

    final dailyAvailabilities = availabilities
        .where((availability) => availability.dayOfWeek == backendDayOfWeek)
        .toList();

    final slots = <int, BookingSlot>{};

    for (final availability in dailyAvailabilities) {
      final startParts = _parseTime(availability.startTime);

      final endParts = _parseTime(availability.endTime);

      if (startParts == null || endParts == null) {
        continue;
      }

      var wallStart = DateTime.utc(
        date.year,
        date.month,
        date.day,
        startParts.$1,
        startParts.$2,
      );

      final availabilityEnd = DateTime.utc(
        date.year,
        date.month,
        date.day,
        endParts.$1,
        endParts.$2,
      );

      while (wallStart.add(appointmentDuration).compareTo(availabilityEnd) <=
          0) {
        final slotStart = AppointmentTimeZone.uniqueLocal(wallStart);
        wallStart = wallStart.add(appointmentDuration);
        if (slotStart == null) continue;
        final slotEnd = AppointmentTimeZone.fromInstant(
          slotStart.toUtc().add(appointmentDuration),
        );
        if (AppointmentTimeZone.uniqueLocal(
                  DateTime.utc(
                    slotEnd.year,
                    slotEnd.month,
                    slotEnd.day,
                    slotEnd.hour,
                    slotEnd.minute,
                  ),
                ) ==
                null ||
            DateTime.utc(
              slotEnd.year,
              slotEnd.month,
              slotEnd.day,
              slotEnd.hour,
              slotEnd.minute,
            ).isAfter(availabilityEnd)) {
          continue;
        }

        final isPast = !slotStart.isAfter(now);

        final isOccupied = dailyOccupiedSlots.any((occupiedSlot) {
          final occupiedStart = occupiedSlot.startUtc.toUtc();

          final occupiedEnd = occupiedSlot.endUtc.toUtc();

          return slotStart.isBefore(occupiedEnd) &&
              slotEnd.isAfter(occupiedStart);
        });

        final isUnavailable = unavailableDates.any((unavailableDate) {
          final unavailableStart = unavailableDate.startUtc.toUtc();

          final unavailableEnd = unavailableDate.endUtc.toUtc();

          return slotStart.isBefore(unavailableEnd) &&
              slotEnd.isAfter(unavailableStart);
        });

        if (!isPast && !isUnavailable) {
          slots[slotStart.microsecondsSinceEpoch] = BookingSlot(
            start: slotStart,
            end: slotEnd,
            isOccupied: isOccupied,
          );
        }
      }
    }

    return slots.values.toList()..sort((a, b) => a.start.compareTo(b.start));
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
