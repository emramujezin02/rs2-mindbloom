class UpdatePrivateJournalEntryRequest {
  final String title;
  final String content;
  final DateTime entryDateUtc;
  final int? moodEntryId;

  const UpdatePrivateJournalEntryRequest({
    required this.title,
    required this.content,
    required this.entryDateUtc,
    required this.moodEntryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title.trim(),
      'content': content.trim(),
      'entryDateUtc':
          entryDateUtc.toUtc().toIso8601String(),
      'moodEntryId': moodEntryId,
    };
  }
}