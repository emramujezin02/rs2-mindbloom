import '../models/create_journal_entry_request.dart';
import '../models/journal_entry_model.dart';
import '../services/journal_api_service.dart';

class JournalRepository {
  final JournalApiService apiService;

  JournalRepository({required this.apiService});

  Future<List<JournalEntryModel>> getMyJournal() {
    return apiService.getMyJournal();
  }

  Future<void> createJournalEntry(CreateJournalEntryRequest request) {
    return apiService.createJournalEntry(request);
  }
}
