import 'therapist_specialization_model.dart';

class TherapistSpecializationPagedResponse {
  final List<TherapistSpecializationModel> items;

  final int pageNumber;

  final int pageSize;

  final int totalCount;

  final int totalPages;

  const TherapistSpecializationPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory TherapistSpecializationPagedResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];

    return TherapistSpecializationPagedResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(TherapistSpecializationModel.fromJson)
                .toList()
          : <TherapistSpecializationModel>[],
      pageNumber: json['pageNumber'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}
