import 'therapist_verification_list_model.dart';

class TherapistVerificationPagedResponse {
  final List<TherapistVerificationListModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const TherapistVerificationPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory TherapistVerificationPagedResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];

    return TherapistVerificationPagedResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(TherapistVerificationListModel.fromJson)
                .toList()
          : [],
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 10,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }
}
