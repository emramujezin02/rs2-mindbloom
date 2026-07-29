class UserSettingsModel {
  final bool notificationsEnabled;
  final bool showProfilePublicly;

  const UserSettingsModel({
    required this.notificationsEnabled,
    required this.showProfilePublicly,
  });

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      showProfilePublicly: json['showProfilePublicly'] as bool? ?? true,
    );
  }
}
