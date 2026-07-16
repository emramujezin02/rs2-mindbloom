import 'admin_review_model.dart';

class AdminReviewsPagedResponse {
  final List<AdminReviewModel> items;

  final int pageNumber;

  final int pageSize;

  final int totalCount;

  final int totalPages;

  const AdminReviewsPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory AdminReviewsPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return AdminReviewsPagedResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(AdminReviewModel.fromJson)
                .toList()
          : [],
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
