import 'admin_user_audit_model.dart';

class AdminUserDetailsModel {
  final int id;

  final String firstName;

  final String lastName;

  final String fullName;

  final String email;

  final String? phoneNumber;

  final DateTime dateOfBirth;

  final String gender;

  final String role;

  final String? profileImageUrl;

  final bool isActive;

  final bool isBlocked;

  final bool isEmailVerified;

  final bool isTwoFactorEnabled;

  final DateTime createdAtUtc;

  final DateTime? lastLoginAtUtc;
  final List<AdminUserAuditModel> auditHistory;

  const AdminUserDetailsModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.role,
    required this.profileImageUrl,
    required this.isActive,
    required this.isBlocked,
    required this.isEmailVerified,
    required this.isTwoFactorEnabled,
    required this.createdAtUtc,
    required this.lastLoginAtUtc,
    required this.auditHistory,
  });

  factory AdminUserDetailsModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';

    final lastName = json['lastName']?.toString() ?? '';

    return AdminUserDetailsModel(
      id: _toInt(json['id']),
      firstName: firstName,
      lastName: lastName,
      fullName: json['fullName']?.toString() ?? '$firstName $lastName',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString(),
      dateOfBirth:
          DateTime.tryParse(json['dateOfBirth']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      gender: json['gender']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      profileImageUrl: json['profileImageUrl']?.toString(),
      isActive: json['isActive'] == true,
      isBlocked: json['isBlocked'] == true,
      isEmailVerified: json['isEmailVerified'] == true,
      isTwoFactorEnabled: json['isTwoFactorEnabled'] == true,
      auditHistory: (json['auditHistory'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                AdminUserAuditModel.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastLoginAtUtc: DateTime.tryParse(
        json['lastLoginAtUtc']?.toString() ?? '',
      )?.toUtc(),
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
}
