class CreateJournalEntryRequest {
  final int mood;
  final String emotion;
  final String note;

  CreateJournalEntryRequest({
    required this.mood,
    required this.emotion,
    required this.note,
  });

  Map<String, dynamic> toJson() {
    return {'mood': mood, 'emotion': emotion, 'note': note};
  }
}
