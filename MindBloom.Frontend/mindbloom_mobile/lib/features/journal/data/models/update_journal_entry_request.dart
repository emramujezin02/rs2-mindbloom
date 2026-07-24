class UpdateJournalEntryRequest {
  final int mood;
  final List<String> emotions;
  final String note;

  const UpdateJournalEntryRequest({
    required this.mood,
    required this.emotions,
    required this.note,
  });

  Map<String, dynamic> toJson() {
    return {'mood': mood, 'emotions': emotions, 'note': note.trim()};
  }
}
