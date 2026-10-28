import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

/// Calendar dates and recurring working hours belong to Sarajevo, not the device.
abstract final class AppointmentTimeZone {
  static final tz.Location location = _load();

  static tz.Location _load() {
    data.initializeTimeZones();
    return tz.getLocation('Europe/Sarajevo');
  }

  static tz.TZDateTime fromInstant(DateTime instant) =>
      tz.TZDateTime.from(instant, location);

  static tz.TZDateTime now() => fromInstant(DateTime.now().toUtc());

  // SQL datetime2 may arrive without a suffix although the API field is UTC.
  static DateTime parseUtc(String value) {
    final hasZone = RegExp(
      r'(Z|[+-]\d{2}:\d{2})$',
      caseSensitive: false,
    ).hasMatch(value);
    return DateTime.parse(hasZone ? value : '${value}Z').toUtc();
  }

  /// Null for gaps and repeated local hours: never silently choose a DST offset.
  static tz.TZDateTime? uniqueLocal(DateTime wall) {
    final encoded = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    );
    final matches = <int, tz.TZDateTime>{};
    for (final offset in location.zones.map((zone) => zone.offset).toSet()) {
      final candidate = fromInstant(encoded.subtract(offset));
      if (candidate.year == wall.year &&
          candidate.month == wall.month &&
          candidate.day == wall.day &&
          candidate.hour == wall.hour &&
          candidate.minute == wall.minute &&
          candidate.second == wall.second &&
          candidate.millisecond == wall.millisecond &&
          candidate.microsecond == wall.microsecond) {
        matches[candidate.microsecondsSinceEpoch] = candidate;
      }
    }
    return matches.length == 1 ? matches.values.single : null;
  }
}
