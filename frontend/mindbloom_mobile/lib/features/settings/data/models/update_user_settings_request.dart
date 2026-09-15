class UpdateUserSettingsRequest {
  final bool notificationsEnabled;
  final bool showProfilePublicly;

  const UpdateUserSettingsRequest({
    required this.notificationsEnabled,
    required this.showProfilePublicly,
  });

  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'showProfilePublicly': showProfilePublicly,
    };
  }
}
