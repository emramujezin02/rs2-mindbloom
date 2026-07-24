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
  DateTime? fromDate;
  DateTime? toDate;

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
        fromUtc: fromDate == null
            ? null
            : DateTime(fromDate!.year, fromDate!.month, fromDate!.day).toUtc(),
        toUtc: toDate == null
            ? null
            : DateTime(
                toDate!.year,
                toDate!.month,
                toDate!.day,
                23,
                59,
                59,
                999,
              ).toUtc(),
      );

      entries = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
        fromUtc: fromDate == null
            ? null
            : DateTime(fromDate!.year, fromDate!.month, fromDate!.day).toUtc(),
        toUtc: toDate == null
            ? null
            : DateTime(
                toDate!.year,
                toDate!.month,
                toDate!.day,
                23,
                59,
                59,
                999,
              ).toUtc(),
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
    required List<String> emotions,
    required String note,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.createJournalEntry(
        CreateJournalEntryRequest(mood: mood, emotions: emotions, note: note),
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
    required List<String> emotions,
    required String note,
  }) async {
    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.updateJournalEntry(
        id: id,
        mood: mood,
        emotions: emotions,
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

  Future<void> applyPeriod({DateTime? from, DateTime? to}) async {
    fromDate = from;
    toDate = to;
    await loadEntries();
  }

  Future<void> clearPeriod() async {
    fromDate = null;
    toDate = null;
    await loadEntries();
  }
}
