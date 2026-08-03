class AdminApplicationInfoModel {
  final String version;

  final String buildNumber;

  final String? environment;

  const AdminApplicationInfoModel({
    required this.version,
    required this.buildNumber,
    required this.environment,
  });

  String get displayVersion {
    if (buildNumber.trim().isEmpty) {
      return version;
    }

    return '$version+$buildNumber';
  }
}
