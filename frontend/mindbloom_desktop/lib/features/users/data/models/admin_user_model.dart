class AdminUserModel {
  final int id;

  final String firstName;

  final String lastName;

  final String fullName;

  final String email;

  final String role;

  final bool isEmailVerified;

  final bool isBlocked;

  final DateTime createdAtUtc;

  const AdminUserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isEmailVerified,
    required this.isBlocked,
    required this.createdAtUtc,
  });

  bool get isActive => !isBlocked;

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString() ?? '';

    final lastName = json['lastName']?.toString() ?? '';

    final returnedFullName = json['fullName']?.toString().trim() ?? '';

    return AdminUserModel(
      id: _toInt(json['id']),
      firstName: firstName,
      lastName: lastName,
      fullName: returnedFullName.isNotEmpty
          ? returnedFullName
          : '$firstName $lastName'.trim(),
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'No Role',
      isEmailVerified: json['isEmailVerified'] == true,
      isBlocked: json['isBlocked'] == true,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  AdminUserModel copyWith({bool? isBlocked}) {
    return AdminUserModel(
      id: id,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      email: email,
      role: role,
      isEmailVerified: isEmailVerified,
      isBlocked: isBlocked ?? this.isBlocked,
      createdAtUtc: createdAtUtc,
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
