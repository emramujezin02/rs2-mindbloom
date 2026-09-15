import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/widgets/app_error_message.dart';
import '../../../journal/data/models/journal_entry_model.dart';
import '../../../journal/data/repositories/journal_repository.dart';
import '../../data/models/private_journal_entry_model.dart';
import '../../data/repositories/private_journal_repository.dart';

class PrivateJournalViewModel extends ChangeNotifier {
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
  String? loadMoreError;
  String? detailsError;
  String? moodEntriesError;

  List<PrivateJournalEntryModel> entries = [];
  List<JournalEntryModel> moodEntries = [];

  PrivateJournalEntryModel? selectedEntry;

  String currentSearch = '';
  DateTime? fromDate;
  DateTime? toDate;

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  Map<String, List<String>> fieldErrors = {};

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadEntries({String? search}) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    loadMoreError = null;
    pageNumber = 1;

    if (search != null) {
      currentSearch = search.trim();
    }

    notifyListeners();

    try {
      final response = await repository.getMyEntries(
        pageNumber: 1,
        pageSize: pageSize,
        search: currentSearch,
        fromUtc: _normalizedFromUtc,
        toUtc: _normalizedToUtc,
      );

      entries = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      error = null;
      loadMoreError = null;
    } catch (exception) {
      error = AppErrorMessage.from(
        exception,
        fallback: 'Privatne zapise nije moguće učitati.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getMyEntries(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        search: currentSearch,
        fromUtc: _normalizedFromUtc,
        toUtc: _normalizedToUtc,
      );

      final existingIds = entries.map((entry) => entry.id).toSet();

      entries.addAll(
        response.items.where((entry) => !existingIds.contains(entry.id)),
      );

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      loadMoreError = null;
    } catch (exception) {
      loadMoreError = AppErrorMessage.from(
        exception,
        fallback: 'Dodatne privatne zapise nije moguće učitati.',
      );
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadMore() => loadMore();

  Future<void> search(String search) {
    return loadEntries(search: search);
  }

  Future<void> clearSearch() {
    currentSearch = '';
    return loadEntries(search: '');
  }

  Future<void> applyDateFilter({DateTime? from, DateTime? to}) async {
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
    if (isLoadingDetails) {
      return;
    }

    isLoadingDetails = true;
    detailsError = null;
    notifyListeners();

    try {
      selectedEntry = await repository.getById(id);
      detailsError = null;
    } catch (exception) {
      detailsError = AppErrorMessage.from(
        exception,
        fallback: 'Detalje privatnog zapisa nije moguće učitati.',
      );
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
    moodEntriesError = null;
    notifyListeners();

    try {
      final response = await journalRepository.getMyJournal(
        pageNumber: 1,
        pageSize: 50,
      );

      moodEntries = response.items;
      moodEntriesError = null;
    } catch (exception) {
      moodEntriesError = AppErrorMessage.from(
        exception,
        fallback: 'Zapise raspoloženja nije moguće učitati.',
      );
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
    fieldErrors = {};
    notifyListeners();

    try {
      await repository.create(
        title: title.trim(),
        content: content.trim(),
        entryDateUtc: entryDate.toUtc(),
        moodEntryId: moodEntryId,
      );

      error = null;
      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Privatni zapis nije moguće sačuvati.');
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
    fieldErrors = {};
    notifyListeners();

    try {
      selectedEntry = await repository.update(
        id: id,
        title: title.trim(),
        content: content.trim(),
        entryDateUtc: entryDate.toUtc(),
        moodEntryId: moodEntryId,
      );

      final index = entries.indexWhere((entry) => entry.id == id);
      if (index != -1 && selectedEntry != null) {
        entries[index] = selectedEntry!;
      }

      error = null;
      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Privatni zapis nije moguće sačuvati.');
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

      entries.removeWhere((entry) => entry.id == id);

      if (selectedEntry?.id == id) {
        selectedEntry = null;
      }

      error = null;
      return true;
    } catch (exception) {
      error = AppErrorMessage.from(
        exception,
        fallback: 'Privatni zapis nije moguće obrisati.',
      );
      return false;
    } finally {
      isDeleting = false;
      notifyListeners();
    }
  }

  String? fieldError(String fieldName) {
    final requested = _normalizeFieldName(fieldName);

    for (final entry in fieldErrors.entries) {
      if (_normalizeFieldName(entry.key) == requested &&
          entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }

    return null;
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void clearLoadMoreError() {
    if (loadMoreError == null) return;
    loadMoreError = null;
    notifyListeners();
  }

  DateTime? get _normalizedFromUtc {
    final date = fromDate;
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day).toUtc();
  }

  DateTime? get _normalizedToUtc {
    final date = toDate;
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999).toUtc();
  }

  void _setError(Object exception, {required String fallback}) {
    if (exception is AppException) {
      error = exception.message.trim().isEmpty
          ? fallback
          : exception.message.trim();

      fieldErrors = Map<String, List<String>>.from(exception.fieldErrors);
      return;
    }

    fieldErrors = {};
    error = AppErrorMessage.from(exception, fallback: fallback);
  }

  String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}
