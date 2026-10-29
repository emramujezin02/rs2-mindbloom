/// A real scheduled interval; absences and times outside working hours are not slots.
class BookingSlot {
  final DateTime start;
  final DateTime end;
  final bool isOccupied;

  const BookingSlot({
    required this.start,
    required this.end,
    required this.isOccupied,
  });

  bool get isAvailable => !isOccupied;
  String? get unavailableReason => isOccupied ? 'Zauzeto' : null;
}
