import 'package:flutter/material.dart';

import '../../../journal/data/models/journal_entry_model.dart';
import '../../../journal/data/repositories/journal_repository.dart';
import '../../data/models/private_journal_entry_model.dart';
import '../../data/repositories/private_journal_repository.dart';

class PrivateJournalViewModel
    extends ChangeNotifier {
  final PrivateJournalRepository repository;
  final JournalRepository journalRepository;

  PrivateJournalViewModel({
    required this.repository,
    required this.journalRepository,
  });

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingDetails = false;
  bool isSaving = false;
  bool isDeleting = false;
  bool isLoadingMoodEntries = false;

  String? error;

  List<PrivateJournalEntryModel> entries = [];

  List<JournalEntryModel> moodEntries = [];

  PrivateJournalEntryModel? selectedEntry;

  String currentSearch = '';

  DateTime? fromDate;
  DateTime? toDate;

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  bool get hasMorePages =>
      pageNumber < totalPages;

  Future<void> loadEntries({
    String? search,
  }) async {
    isLoading = true;
    error = null;
    pageNumber = 1;

    if (search != null) {
      currentSearch = search.trim();
    }

    notifyListeners();

    try {
      final response =
          await repository.getMyEntries(
        pageNumber: pageNumber,
        pageSize: pageSize,
        search: currentSearch,
        fromUtc: _normalizedFromUtc,
        toUtc: _normalizedToUtc,
      );

      entries = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      error = _normalizeError(exception);
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
      final response =
          await repository.getMyEntries(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        search: currentSearch,
        fromUtc: _normalizedFromUtc,
        toUtc: _normalizedToUtc,
      );

      entries.addAll(response.items);
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> search(String search) async {
    await loadEntries(search: search);
  }

  Future<void> clearSearch() async {
    currentSearch = '';
    await loadEntries(search: '');
  }

  Future<void> applyDateFilter({
    DateTime? from,
    DateTime? to,
  }) async {
    fromDate = from;
    toDate = to;

    await loadEntries();
  }

  Future<void> clearDateFilter() async {
    fromDate = null;
    toDate = null;

    await loadEntries();
  }

  Future<void> loadDetails(int id) async {
    isLoadingDetails = true;
    error = null;
    notifyListeners();

    try {
      selectedEntry =
          await repository.getById(id);
    } catch (exception) {
      selectedEntry = null;
      error = _normalizeError(exception);
    } finally {
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  Future<void> loadMoodEntries() async {
    if (isLoadingMoodEntries) {
      return;
    }

    isLoadingMoodEntries = true;
    error = null;
    notifyListeners();

    try {
      final response =
          await journalRepository.getMyJournal(
        pageNumber: 1,
        pageSize: 50,
      );

      moodEntries = response.items;
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoadingMoodEntries = false;
      notifyListeners();
    }
  }

  Future<bool> createEntry({
    required String title,
    required String content,
    required DateTime entryDate,
    int? moodEntryId,
  }) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.create(
        title: title,
        content: content,
        entryDateUtc: entryDate.toUtc(),
        moodEntryId: moodEntryId,
      );

      return true;
    } catch (exception) {
      error = _normalizeError(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateEntry({
    required int id,
    required String title,
    required String content,
    required DateTime entryDate,
    int? moodEntryId,
  }) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      selectedEntry =
          await repository.update(
        id: id,
        title: title,
        content: content,
        entryDateUtc: entryDate.toUtc(),
        moodEntryId: moodEntryId,
      );

      return true;
    } catch (exception) {
      error = _normalizeError(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEntry(int id) async {
    if (isDeleting) {
      return false;
    }

    isDeleting = true;
    error = null;
    notifyListeners();

    try {
      await repository.delete(id);

      entries.removeWhere(
        (entry) => entry.id == id,
      );

      if (selectedEntry?.id == id) {
        selectedEntry = null;
      }

      return true;
    } catch (exception) {
      error = _normalizeError(exception);

      return false;
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  DateTime? get _normalizedFromUtc {
    final date = fromDate;

    if (date == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
    ).toUtc();
  }

  DateTime? get _normalizedToUtc {
    final date = toDate;

    if (date == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
      999,
    ).toUtc();
  }

  String _normalizeError(Object exception) {
    return exception
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '');
  }
}