import 'therapist_client_appointment_model.dart';
import 'therapist_client_membership_model.dart';
import 'therapist_client_review_model.dart';

class TherapistClientDetailsModel {
  final int clientId;
  final int userId;
  final String fullName;
  final String email;
  final String? phoneNumber;

  final int totalAppointments;
  final int pendingAppointments;
  final int acceptedAppointments;
  final int completedAppointments;
  final int cancelledAppointments;

  final DateTime? firstAppointmentDate;
  final DateTime? lastAppointmentDate;
  final DateTime? nextAppointmentDate;

  final List<TherapistClientAppointmentModel> appointmentHistory;

  final List<TherapistClientMembershipModel> memberships;

  final List<TherapistClientReviewModel> reviews;

  const TherapistClientDetailsModel({
    required this.clientId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.totalAppointments,
    required this.pendingAppointments,
    required this.acceptedAppointments,
    required this.completedAppointments,
    required this.cancelledAppointments,
    required this.appointmentHistory,
    required this.memberships,
    required this.reviews,
    this.phoneNumber,
    this.firstAppointmentDate,
    this.lastAppointmentDate,
    this.nextAppointmentDate,
  });

  factory TherapistClientDetailsModel.fromJson(Map<String, dynamic> json) {
    final historyValue = json['appointmentHistory'];

    final history = historyValue is List
        ? historyValue
              .whereType<Map>()
              .map(
                (item) => TherapistClientAppointmentModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <TherapistClientAppointmentModel>[];

    final membershipsValue = json['memberships'];

    final memberships = membershipsValue is List
        ? membershipsValue
              .whereType<Map>()
              .map(
                (item) => TherapistClientMembershipModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <TherapistClientMembershipModel>[];

    final reviewsValue = json['reviews'];

    final reviews = reviewsValue is List
        ? reviewsValue
              .whereType<Map>()
              .map(
                (item) => TherapistClientReviewModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <TherapistClientReviewModel>[];

    return TherapistClientDetailsModel(
      clientId: _toInt(json['clientId']),
      userId: _toInt(json['userId']),
      fullName: _readFullName(json),
      email: _toString(json['email']),
      phoneNumber: _toNullableString(json['phoneNumber']),
      totalAppointments: _toInt(json['totalAppointments']),
      pendingAppointments: _toInt(json['pendingAppointments']),
      acceptedAppointments: _toInt(json['acceptedAppointments']),
      completedAppointments: _toInt(json['completedAppointments']),
      cancelledAppointments: _toInt(json['cancelledAppointments']),
      firstAppointmentDate: _toNullableDateTime(json['firstAppointmentDate']),
      lastAppointmentDate: _toNullableDateTime(json['lastAppointmentDate']),
      nextAppointmentDate: _toNullableDateTime(json['nextAppointmentDate']),
      appointmentHistory: history,
      memberships: memberships,
      reviews: reviews,
    );
  }

  static String _readFullName(Map<String, dynamic> json) {
    final fullName = _toString(json['fullName']);

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final firstName = _toString(json['firstName']);

    final lastName = _toString(json['lastName']);

    final combinedName = '$firstName $lastName'.trim();

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

  static DateTime? _toNullableDateTime(dynamic value) {
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
