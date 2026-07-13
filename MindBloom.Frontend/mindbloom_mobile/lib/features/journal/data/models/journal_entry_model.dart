class JournalEntryModel {
  final int id;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final int mood;
  final String emotion;
  final String note;

  JournalEntryModel({
    required this.id,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.mood,
    required this.emotion,
    required this.note,
  });

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    final updatedAtValue = json['updatedAtUtc'];

    return JournalEntryModel(
      id: json['id'] ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      updatedAtUtc: updatedAtValue is String && updatedAtValue.isNotEmpty
          ? DateTime.tryParse(updatedAtValue)
          : null,
      mood: json['mood'] ?? 0,
      emotion: json['emotion'] ?? '',
      note: json['note'] ?? '',
    );
  }
}
