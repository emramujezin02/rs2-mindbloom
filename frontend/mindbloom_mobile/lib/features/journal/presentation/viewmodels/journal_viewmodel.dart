import 'package:flutter/material.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/widgets/app_error_message.dart';
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
  String? loadMoreError;

  List<JournalEntryModel> entries = [];

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  Map<String, List<String>> fieldErrors = {};

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadEntries() async {
    if (isLoading) return;

    isLoading = true;
    error = null;
    loadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getMyJournal(
        pageNumber: 1,
        pageSize: pageSize,
        fromUtc: _fromUtc,
        toUtc: _toUtc,
      );

      entries = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      error = null;
      loadMoreError = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || isLoading || !hasMorePages) return;

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getMyJournal(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        fromUtc: _fromUtc,
        toUtc: _toUtc,
      );

      final existingIds = entries.map((entry) => entry.id).toSet();
      entries.addAll(
        response.items.where((entry) => !existingIds.contains(entry.id)),
      );

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      loadMoreError = null;
    } catch (exception) {
      loadMoreError = AppErrorMessage.from(exception);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadMore() => loadMore();

  Future<JournalEntryModel?> getEntry(int id) async {
    error = null;
    notifyListeners();

    try {
      final entry = await repository.getJournalEntry(id);
      error = null;
      return entry;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
      notifyListeners();
      return null;
    }
  }

  Future<bool> createEntry({
    required int mood,
    required List<String> emotions,
    required String note,
  }) async {
    if (isSaving) return false;

    isSaving = true;
    error = null;
    fieldErrors = {};
    notifyListeners();

    try {
      await repository.createJournalEntry(
        CreateJournalEntryRequest(mood: mood, emotions: emotions, note: note),
      );
      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Zapis dnevnika nije moguće sačuvati.');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateEntry({
    required int id,
    required int mood,
    required List<String> emotions,
    required String note,
  }) async {
    if (isSaving) return false;

    isSaving = true;
    error = null;
    fieldErrors = {};
    notifyListeners();

    try {
      await repository.updateJournalEntry(
        id: id,
        mood: mood,
        emotions: emotions,
        note: note,
      );
      return true;
    } catch (exception) {
      _setError(exception, fallback: 'Zapis dnevnika nije moguće sačuvati.');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEntry(int id) async {
    error = null;
    notifyListeners();

    try {
      await repository.deleteJournalEntry(id);
      entries.removeWhere((entry) => entry.id == id);
      return true;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
      return false;
    } finally {
      notifyListeners();
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

  DateTime? get _fromUtc {
    final value = fromDate;
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day).toUtc();
  }

  DateTime? get _toUtc {
    final value = toDate;
    if (value == null) return null;
    return DateTime(
      value.year,
      value.month,
      value.day,
      23,
      59,
      59,
      999,
    ).toUtc();
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
    final message = AppErrorMessage.from(exception).trim();
    error = message.isEmpty ? fallback : message;
  }

  String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }
}
