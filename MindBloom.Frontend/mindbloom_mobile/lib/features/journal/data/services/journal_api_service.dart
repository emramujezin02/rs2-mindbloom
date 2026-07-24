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
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final parameters = <String>['pageNumber=$pageNumber', 'pageSize=$pageSize'];

    if (fromUtc != null) {
      parameters.add(
        'fromUtc=${Uri.encodeQueryComponent(fromUtc.toUtc().toIso8601String())}',
      );
    }

    if (toUtc != null) {
      parameters.add(
        'toUtc=${Uri.encodeQueryComponent(toUtc.toUtc().toIso8601String())}',
      );
    }

    final response = await apiClient.get(
      '/JournalEntries/mine?${parameters.join('&')}',
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
