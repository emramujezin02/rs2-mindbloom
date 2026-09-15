class TherapistClientAppointmentModel {
  final int appointmentId;
  final DateTime startUtc;
  final DateTime endUtc;
  final String status;
  final String type;
  final String? meetingLink;
  final String? location;
  final bool hasNote;

  const TherapistClientAppointmentModel({
    required this.appointmentId,
    required this.startUtc,
    required this.endUtc,
    required this.status,
    required this.type,
    required this.hasNote,
    this.meetingLink,
    this.location,
  });

  factory TherapistClientAppointmentModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TherapistClientAppointmentModel(
      appointmentId: _toInt(json['appointmentId']),
      startUtc: _toDateTime(json['startUtc']),
      endUtc: _toDateTime(json['endUtc']),
      status: _toString(json['status']),
      type: _toString(json['type']),
      meetingLink: _toNullableString(json['meetingLink']),
      location: _toNullableString(json['location']),
      hasNote: _toBool(json['hasNote']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _toNullableString(dynamic value) {
    final parsed = value?.toString().trim();

    if (parsed == null || parsed.isEmpty) {
      return null;
    }

    return parsed;
  }

  static DateTime _toDateTime(dynamic value) {
    final parsed = DateTime.tryParse(
      value?.toString() ?? '',
    );

    return parsed ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        );
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final parsed = value?.toString().trim().toLowerCase();

    return parsed == 'true' || parsed == '1';
  }
}