import 'article_management_model.dart';

class ArticlePagedResponse {
  final List<ArticleManagementModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const ArticlePagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory ArticlePagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return ArticlePagedResponse(
      items: rawItems
          .map(
            (item) => ArticleManagementModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      pageNumber: json['pageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
