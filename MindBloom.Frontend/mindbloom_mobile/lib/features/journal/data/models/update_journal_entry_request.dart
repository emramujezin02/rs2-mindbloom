class UpdateJournalEntryRequest {
  final int mood;
  final String emotion;
  final String note;

  UpdateJournalEntryRequest({
    required this.mood,
    required this.emotion,
    required this.note,
  });

  Map<String, dynamic> toJson() {
    return {'mood': mood, 'emotion': emotion, 'note': note};
  }
}
