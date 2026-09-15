class PrivateJournalEntryModel {
  final int id;
  final String title;
  final String content;
  final DateTime entryDateUtc;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final int? moodEntryId;
  final int? mood;
  final List<String> emotions;

  const PrivateJournalEntryModel({
    required this.id,
    required this.title,
    required this.content,
    required this.entryDateUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.moodEntryId,
    required this.mood,
    required this.emotions,
  });

  factory PrivateJournalEntryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawEmotions = json['emotions'];

    return PrivateJournalEntryModel(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      entryDateUtc: DateTime.parse(
        json['entryDateUtc'].toString(),
      ),
      createdAtUtc: DateTime.parse(
        json['createdAtUtc'].toString(),
      ),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.tryParse(
              json['updatedAtUtc'].toString(),
            ),
      moodEntryId: json['moodEntryId'] as int?,
      mood: json['mood'] as int?,
      emotions: rawEmotions is List
          ? rawEmotions
                .map((item) => item.toString())
                .where(
                  (item) => item.trim().isNotEmpty,
                )
                .toList()
          : [],
    );
  }
}