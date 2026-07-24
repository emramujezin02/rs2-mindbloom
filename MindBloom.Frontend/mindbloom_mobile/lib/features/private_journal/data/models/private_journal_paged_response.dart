import 'private_journal_entry_model.dart';

class PrivateJournalPagedResponse {
  final List<PrivateJournalEntryModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const PrivateJournalPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory PrivateJournalPagedResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];

    return PrivateJournalPagedResponse(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) =>
                      PrivateJournalEntryModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : [],
      pageNumber: json['pageNumber'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 10,
      totalCount: json['totalCount'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
    );
  }
}