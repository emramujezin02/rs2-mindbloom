class CreateJournalEntryRequest {
  final int mood;
  final List<String> emotions;
  final String note;

  const CreateJournalEntryRequest({
    required this.mood,
    required this.emotions,
    required this.note,
  });

  Map<String, dynamic> toJson() {
    return {'mood': mood, 'emotions': emotions, 'note': note.trim()};
  }
}
