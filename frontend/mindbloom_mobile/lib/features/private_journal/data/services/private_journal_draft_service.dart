import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PrivateJournalDraft {
  final String title;
  final String content;
  final DateTime entryDate;
  final int? moodEntryId;

  const PrivateJournalDraft({
    required this.title,
    required this.content,
    required this.entryDate,
    required this.moodEntryId,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'entryDate':
          entryDate.toIso8601String(),
      'moodEntryId': moodEntryId,
    };
  }

  factory PrivateJournalDraft.fromJson(
    Map<String, dynamic> json,
  ) {
    return PrivateJournalDraft(
      title: json['title']?.toString() ?? '',
      content:
          json['content']?.toString() ?? '',
      entryDate: DateTime.tryParse(
            json['entryDate']?.toString() ?? '',
          ) ??
          DateTime.now(),
      moodEntryId: json['moodEntryId'] as int?,
    );
  }
}

class PrivateJournalDraftService {
  static const String _draftKey =
      'private_journal_create_draft';

  Future<void> save(
    PrivateJournalDraft draft,
  ) async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      _draftKey,
      jsonEncode(draft.toJson()),
    );
  }

  Future<PrivateJournalDraft?> load() async {
    final preferences =
        await SharedPreferences.getInstance();

    final rawDraft =
        preferences.getString(_draftKey);

    if (rawDraft == null ||
        rawDraft.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawDraft);

      if (decoded is! Map) {
        return null;
      }

      return PrivateJournalDraft.fromJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.remove(_draftKey);
  }
}