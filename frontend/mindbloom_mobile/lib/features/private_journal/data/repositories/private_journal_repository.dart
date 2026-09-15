import '../models/create_private_journal_entry_request.dart';
import '../models/private_journal_entry_model.dart';
import '../models/private_journal_paged_response.dart';
import '../models/update_private_journal_entry_request.dart';
import '../services/private_journal_api_service.dart';

class PrivateJournalRepository {
  final PrivateJournalApiService apiService;

  PrivateJournalRepository({
    required this.apiService,
  });

  Future<PrivateJournalPagedResponse>
      getMyEntries({
    required int pageNumber,
    required int pageSize,
    String? search,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    return apiService.getMyEntries(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
  }

  Future<PrivateJournalEntryModel>
      getById(int id) {
    return apiService.getById(id);
  }

  Future<PrivateJournalEntryModel>
      create({
    required String title,
    required String content,
    required DateTime entryDateUtc,
    int? moodEntryId,
  }) {
    return apiService.create(
      CreatePrivateJournalEntryRequest(
        title: title,
        content: content,
        entryDateUtc: entryDateUtc,
        moodEntryId: moodEntryId,
      ),
    );
  }

  Future<PrivateJournalEntryModel>
      update({
    required int id,
    required String title,
    required String content,
    required DateTime entryDateUtc,
    int? moodEntryId,
  }) {
    return apiService.update(
      id: id,
      request: UpdatePrivateJournalEntryRequest(
        title: title,
        content: content,
        entryDateUtc: entryDateUtc,
        moodEntryId: moodEntryId,
      ),
    );
  }

  Future<void> delete(int id) {
    return apiService.delete(id);
  }
}