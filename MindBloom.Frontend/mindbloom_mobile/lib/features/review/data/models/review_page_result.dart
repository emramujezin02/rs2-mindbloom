import 'review_model.dart';

class ReviewPageResult {
  final List<ReviewModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;

  const ReviewPageResult({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
  });

  bool get hasMore {
    return pageNumber * pageSize < totalCount;
  }

  factory ReviewPageResult.fromJson(
    Map<String, dynamic> json, {
    required int requestedPage,
    required int requestedPageSize,
  }) {
    final itemsValue = json['items'];

    final items = itemsValue is List
        ? itemsValue
              .whereType<Map>()
              .map(
                (item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ReviewModel>[];

    return ReviewPageResult(
      items: items,
      pageNumber: _toInt(json['pageNumber'], requestedPage),
      pageSize: _toInt(json['pageSize'], requestedPageSize),
      totalCount: _toInt(
        json['totalCount'] ?? json['totalItems'],
        items.length,
      ),
    );
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
