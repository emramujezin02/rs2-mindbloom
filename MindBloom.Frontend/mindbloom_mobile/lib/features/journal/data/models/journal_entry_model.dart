class JournalEntryModel {
  final int id;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final int mood;
  final List<String> emotions;
  final String note;

  const JournalEntryModel({
    required this.id,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.mood,
    required this.emotions,
    required this.note,
  });

  factory JournalEntryModel.fromJson(Map<String, dynamic> json) {
    final rawEmotions = json['emotions'];

    return JournalEntryModel(
      id: json['id'] as int? ?? 0,
      createdAtUtc: DateTime.parse(json['createdAtUtc'].toString()),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.tryParse(json['updatedAtUtc'].toString()),
      mood: json['mood'] as int? ?? 3,
      emotions: rawEmotions is List
          ? rawEmotions
                .map((item) => item.toString())
                .where((item) => item.trim().isNotEmpty)
                .toList()
          : [],
      note: json['note']?.toString() ?? '',
    );
  }
}
