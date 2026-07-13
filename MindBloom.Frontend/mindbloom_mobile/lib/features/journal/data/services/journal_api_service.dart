import '../../../../core/network/api_client.dart';
import '../models/create_journal_entry_request.dart';
import '../models/journal_entry_model.dart';
import '../models/journal_paged_response.dart';
import '../models/update_journal_entry_request.dart';

class JournalApiService {
  final ApiClient apiClient;

  JournalApiService({required this.apiClient});

  Future<JournalPagedResponse> getMyJournal({
    required int pageNumber,
    required int pageSize,
  }) async {
    final response = await apiClient.get(
      '/JournalEntries/mine'
      '?pageNumber=$pageNumber'
      '&pageSize=$pageSize',
    );

    return JournalPagedResponse.fromJson(response as Map<String, dynamic>);
  }

  Future<JournalEntryModel> getJournalEntry(int id) async {
    final response = await apiClient.get('/JournalEntries/$id');

    return JournalEntryModel.fromJson(response as Map<String, dynamic>);
  }

  Future<JournalEntryModel> createJournalEntry(
    CreateJournalEntryRequest request,
  ) async {
    final response = await apiClient.post(
      '/JournalEntries',
      body: request.toJson(),
    );

    return JournalEntryModel.fromJson(response as Map<String, dynamic>);
  }

  Future<JournalEntryModel> updateJournalEntry(
    int id,
    UpdateJournalEntryRequest request,
  ) async {
    final response = await apiClient.put(
      '/JournalEntries/$id',
      body: request.toJson(),
    );

    return JournalEntryModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteJournalEntry(int id) async {
    await apiClient.delete('/JournalEntries/$id');
  }
}
