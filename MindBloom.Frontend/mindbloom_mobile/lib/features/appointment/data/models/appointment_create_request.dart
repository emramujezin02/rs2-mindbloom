class AppointmentCreateRequest {
  final int therapistId;
  final DateTime startUtc;
  final DateTime endUtc;
  final int type;
  final String? meetingLink;
  final String? location;

  AppointmentCreateRequest({
    required this.therapistId,
    required this.startUtc,
    required this.endUtc,
    required this.type,
    this.meetingLink,
    this.location,
  });

  Map<String, dynamic> toJson() {
    return {
      'therapistId': therapistId,
      'startUtc': startUtc.toIso8601String(),
      'endUtc': endUtc.toIso8601String(),
      'type': type,
      'meetingLink': meetingLink,
      'location': location,
    };
  }
}
