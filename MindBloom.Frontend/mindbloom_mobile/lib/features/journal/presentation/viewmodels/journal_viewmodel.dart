import 'package:flutter/material.dart';

import '../../data/models/create_journal_entry_request.dart';
import '../../data/models/journal_entry_model.dart';
import '../../data/repositories/journal_repository.dart';

class JournalViewModel extends ChangeNotifier {
  final JournalRepository repository;

  JournalViewModel({required this.repository});

  bool isLoading = false;
  String? error;

  List<JournalEntryModel> entries = [];

  Future<void> loadEntries() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      entries = await repository.getMyJournal();
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> createEntry({
    required int mood,
    required String emotion,
    required String note,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      await repository.createJournalEntry(
        CreateJournalEntryRequest(mood: mood, emotion: emotion, note: note),
      );

      await loadEntries();

      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();

      return false;
    }
  }
}
