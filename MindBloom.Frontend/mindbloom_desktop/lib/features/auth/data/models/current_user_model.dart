class CurrentUserModel {
  final int userId;
  final String email;
  final String username;
  final String role;

  const CurrentUserModel({
    required this.userId,
    required this.email,
    required this.username,
    required this.role,
  });

  factory CurrentUserModel.fromJson(Map<String, dynamic> json) {
    return CurrentUserModel(
      userId: int.tryParse(json['userId']?.toString() ?? '') ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      role: json['role'] ?? '',
    );
  }

  bool get isAdmin {
    return role.trim().toLowerCase() == 'admin';
  }
}
