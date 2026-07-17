import 'workshop_registration_model.dart';

class WorkshopRegistrationPagedResponse {
  final List<WorkshopRegistrationModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const WorkshopRegistrationPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory WorkshopRegistrationPagedResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'] as List? ?? [];

    return WorkshopRegistrationPagedResponse(
      items: rawItems
          .map(
            (item) => WorkshopRegistrationModel.fromJson(
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
