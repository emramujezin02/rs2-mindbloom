import 'article_model.dart';

class ArticlePagedResponse {
  final List<ArticleModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  ArticlePagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory ArticlePagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return ArticlePagedResponse(
      items: rawItems is List
          ? rawItems
                .map(
                  (item) => ArticleModel.fromJson(item as Map<String, dynamic>),
                )
                .toList()
          : [],
      pageNumber: json['pageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
