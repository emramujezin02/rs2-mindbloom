class TherapistClientModel {
  final int clientId;
  final int userId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final int totalAppointments;
  final int completedAppointments;
  final DateTime? lastAppointmentDate;
  final DateTime? nextAppointmentDate;

  const TherapistClientModel({
    required this.clientId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.totalAppointments,
    required this.completedAppointments,
    this.phoneNumber,
    this.lastAppointmentDate,
    this.nextAppointmentDate,
  });

  factory TherapistClientModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TherapistClientModel(
      clientId: _toInt(json['clientId']),
      userId: _toInt(json['userId']),
      fullName: _readFullName(json),
      email: _toString(json['email']),
      phoneNumber: _toNullableString(
        json['phoneNumber'],
      ),
      totalAppointments: _toInt(
        json['totalAppointments'],
      ),
      completedAppointments: _toInt(
        json['completedAppointments'],
      ),
      lastAppointmentDate: _toNullableDateTime(
        json['lastAppointmentDate'],
      ),
      nextAppointmentDate: _toNullableDateTime(
        json['nextAppointmentDate'],
      ),
    );
  }

  static String _readFullName(
    Map<String, dynamic> json,
  ) {
    final fullName = _toString(json['fullName']);

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final firstName = _toString(json['firstName']);
    final lastName = _toString(json['lastName']);

    final combinedName =
        '$firstName $lastName'.trim();

    if (combinedName.isNotEmpty) {
      return combinedName;
    }

    return 'Client';
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
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

  static DateTime? _toNullableDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }
}