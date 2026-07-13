import 'package:flutter/material.dart';

import '../../data/models/create_journal_entry_request.dart';
import '../../data/models/journal_entry_model.dart';
import '../../data/repositories/journal_repository.dart';

class JournalViewModel extends ChangeNotifier {
  final JournalRepository repository;

  JournalViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isSaving = false;

  String? error;

  List<JournalEntryModel> entries = [];

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadEntries() async {
    isLoading = true;
    error = null;
    pageNumber = 1;
    notifyListeners();

    try {
      final response = await repository.getMyJournal(
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      entries = response.items;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    error = null;
    notifyListeners();

    try {
      final nextPage = pageNumber + 1;

      final response = await repository.getMyJournal(
        pageNumber: nextPage,
        pageSize: pageSize,
      );

      entries.addAll(response.items);

      pageNumber = response.pageNumber;

      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingMore = false;
    notifyListeners();
  }

  Future<JournalEntryModel?> getEntry(int id) async {
    try {
      return await repository.getJournalEntry(id);
    } catch (exception) {
      error = exception.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> createEntry({
    required int mood,
    required String emotion,
    required String note,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.createJournalEntry(
        CreateJournalEntryRequest(mood: mood, emotion: emotion, note: note),
      );

      isSaving = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isSaving = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> updateEntry({
    required int id,
    required int mood,
    required String emotion,
    required String note,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.updateJournalEntry(
        id: id,
        mood: mood,
        emotion: emotion,
        note: note,
      );

      isSaving = false;
      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      isSaving = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> deleteEntry(int id) async {
    error = null;

    try {
      await repository.deleteJournalEntry(id);

      entries.removeWhere((entry) => entry.id == id);

      notifyListeners();

      return true;
    } catch (exception) {
      error = exception.toString();
      notifyListeners();

      return false;
    }
  }
}
