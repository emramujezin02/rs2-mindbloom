import 'admin_membership_model.dart';

class AdminMembershipPagedResponse {
  final List<AdminMembershipModel> items;

  final int pageNumber;

  final int pageSize;

  final int totalCount;

  final int totalPages;

  const AdminMembershipPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory AdminMembershipPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return AdminMembershipPagedResponse(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(AdminMembershipModel.fromJson)
          .toList(),
      pageNumber: json['pageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
