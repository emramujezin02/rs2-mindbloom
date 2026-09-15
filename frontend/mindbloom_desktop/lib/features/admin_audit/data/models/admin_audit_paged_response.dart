import 'admin_audit_log_model.dart';

class AdminAuditPagedResponse {
  final List<AdminAuditLogModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const AdminAuditPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory AdminAuditPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return AdminAuditPagedResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => AdminAuditLogModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      pageNumber: _toInt(json['pageNumber'], fallback: 1),
      pageSize: _toInt(json['pageSize'], fallback: 10),
      totalCount: _toInt(json['totalCount']),
      totalPages: _toInt(json['totalPages']),
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
