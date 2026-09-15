class AdminAccountSettingsModel {
  final bool notificationsEnabled;

  final bool showProfilePublicly;

  const AdminAccountSettingsModel({
    required this.notificationsEnabled,
    required this.showProfilePublicly,
  });

  factory AdminAccountSettingsModel.fromJson(Map<String, dynamic> json) {
    return AdminAccountSettingsModel(
      notificationsEnabled: json['notificationsEnabled'] == true,
      showProfilePublicly: json['showProfilePublicly'] == true,
    );
  }
}
