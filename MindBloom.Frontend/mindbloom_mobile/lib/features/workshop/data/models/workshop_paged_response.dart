import 'workshop_model.dart';

class WorkshopPagedResponse {
  final List<WorkshopModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  WorkshopPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory WorkshopPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return WorkshopPagedResponse(
      items: rawItems is List
          ? rawItems
                .map(
                  (item) =>
                      WorkshopModel.fromJson(item as Map<String, dynamic>),
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
