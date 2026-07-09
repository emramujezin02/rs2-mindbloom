import '../../../../core/network/api_client.dart';
import '../models/create_journal_entry_request.dart';
import '../models/journal_entry_model.dart';

class JournalApiService {
  final ApiClient apiClient;

  JournalApiService({required this.apiClient});

  Future<List<JournalEntryModel>> getMyJournal() async {
    final response = await apiClient.get('/JournalEntries/mine');

    return (response as List)
        .map((e) => JournalEntryModel.fromJson(e))
        .toList();
  }

  Future<void> createJournalEntry(CreateJournalEntryRequest request) async {
    await apiClient.post('/JournalEntries', body: request.toJson());
  }
}
