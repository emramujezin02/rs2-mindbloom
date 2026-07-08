class AppointmentCreateRequest {
  final int therapistId;
  final DateTime startTimeUtc;
  final String type;
  final String? notes;

  AppointmentCreateRequest({
    required this.therapistId,
    required this.startTimeUtc,
    required this.type,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      "therapistId": therapistId,
      "startTimeUtc": startTimeUtc.toIso8601String(),
      "type": type,
      "notes": notes,
    };
  }
}
