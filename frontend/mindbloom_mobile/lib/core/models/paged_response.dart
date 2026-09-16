class PagedResponse<T> {
  final List<T> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasPreviousPage;
  final bool hasNextPage;

  const PagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });

  factory PagedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final rawItems = json['items'];
    final pageNumber = json['pageNumber'] as int? ?? 1;
    final totalPages = json['totalPages'] as int? ?? 0;

    return PagedResponse<T>(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((item) => fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : [],
      pageNumber: pageNumber,
      pageSize: json['pageSize'] as int? ?? 10,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: totalPages,
      hasPreviousPage: json['hasPreviousPage'] as bool? ?? pageNumber > 1,
      hasNextPage: json['hasNextPage'] as bool? ?? pageNumber < totalPages,
    );
  }
}
