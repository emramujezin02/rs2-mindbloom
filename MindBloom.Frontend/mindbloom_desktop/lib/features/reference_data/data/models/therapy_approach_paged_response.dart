import 'therapy_approach_model.dart';

class TherapyApproachPagedResponse {
  final List<TherapyApproachModel> items;

  final int pageNumber;

  final int pageSize;

  final int totalCount;

  final int totalPages;

  const TherapyApproachPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory TherapyApproachPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return TherapyApproachPagedResponse(
      items: rawItems
          .map(
            (item) => TherapyApproachModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      pageNumber: json['pageNumber'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}
