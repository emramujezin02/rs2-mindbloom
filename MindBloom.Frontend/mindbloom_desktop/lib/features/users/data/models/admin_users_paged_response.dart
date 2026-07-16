import 'admin_user_model.dart';

class AdminUsersPagedResponse {
  final List<AdminUserModel> items;

  final int pageNumber;

  final int pageSize;

  final int totalCount;

  final int totalPages;

  const AdminUsersPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory AdminUsersPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return AdminUsersPagedResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(AdminUserModel.fromJson)
                .toList()
          : <AdminUserModel>[],
      pageNumber: _toInt(json['pageNumber']),
      pageSize: _toInt(json['pageSize']),
      totalCount: _toInt(json['totalCount']),
      totalPages: _toInt(json['totalPages']),
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
