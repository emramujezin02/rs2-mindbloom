class JournalEntryModel {
  final int id;
  final DateTime createdAtUtc;
  final int mood;
  final String emotion;
  final String note;

  JournalEntryModel({
    required this.id,
    required this.createdAtUtc,
    required this.mood,
    required this.emotion,
    required this.note,
  });

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    return JournalEntryModel(
      id: json['id'],
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      mood: json['mood'],
      emotion: json['emotion'] ?? '',
      note: json['note'] ?? '',
    );
  }
}
