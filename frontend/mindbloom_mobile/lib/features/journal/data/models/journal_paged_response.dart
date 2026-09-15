import 'journal_entry_model.dart';

class JournalPagedResponse {
  final List<JournalEntryModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  JournalPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory JournalPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    return JournalPagedResponse(
      items: rawItems is List
          ? rawItems
                .map(
                  (item) =>
                      JournalEntryModel.fromJson(item as Map<String, dynamic>),
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
