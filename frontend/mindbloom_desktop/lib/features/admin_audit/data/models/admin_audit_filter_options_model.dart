class AdminAuditUserOptionModel {
  final int id;
  final String fullName;
  final String email;

  const AdminAuditUserOptionModel({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory AdminAuditUserOptionModel.fromJson(Map<String, dynamic> json) {
    return AdminAuditUserOptionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }
}

class AdminAuditFilterOptionsModel {
  final List<AdminAuditUserOptionModel> users;

  final List<String> actions;

  final List<String> entityTypes;

  const AdminAuditFilterOptionsModel({
    required this.users,
    required this.actions,
    required this.entityTypes,
  });

  factory AdminAuditFilterOptionsModel.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    final rawActions = json['actions'];
    final rawEntityTypes = json['entityTypes'];

    return AdminAuditFilterOptionsModel(
      users: rawUsers is List
          ? rawUsers
                .whereType<Map>()
                .map(
                  (item) => AdminAuditUserOptionModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.id > 0)
                .toList()
          : const [],
      actions: rawActions is List
          ? rawActions
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      entityTypes: rawEntityTypes is List
          ? rawEntityTypes
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
    );
  }
}
