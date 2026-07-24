import '../models/create_journal_entry_request.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_paged_response.dart';
import '../models/update_journal_entry_request.dart';
import '../services/journal_api_service.dart';

class JournalRepository {
  final JournalApiService apiService;

  JournalRepository({required this.apiService});

  Future<JournalPagedResponse> getMyJournal({
    required int pageNumber,
    required int pageSize,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    return apiService.getMyJournal(
      pageNumber: pageNumber,
      pageSize: pageSize,
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
  }

  Future<JournalEntryModel> getJournalEntry(int id) {
    return apiService.getJournalEntry(id);
  }

  Future<JournalEntryModel> createJournalEntry(
    CreateJournalEntryRequest request,
  ) {
    return apiService.createJournalEntry(request);
  }

  Future<JournalEntryModel> updateJournalEntry({
    required int id,
    required int mood,
    required List<String> emotions,
    required String note,
  }) {
    return apiService.updateJournalEntry(
      id,
      UpdateJournalEntryRequest(mood: mood, emotions: emotions, note: note),
    );
  }

  Future<void> deleteJournalEntry(int id) {
    return apiService.deleteJournalEntry(id);
  }
}
