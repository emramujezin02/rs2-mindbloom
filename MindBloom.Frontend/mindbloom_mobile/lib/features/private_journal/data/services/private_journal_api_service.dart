import '../../../../core/network/api_client.dart';
import '../models/create_private_journal_entry_request.dart';
import '../models/private_journal_entry_model.dart';
import '../models/private_journal_paged_response.dart';
import '../models/update_private_journal_entry_request.dart';

class PrivateJournalApiService {
  final ApiClient apiClient;

  PrivateJournalApiService({
    required this.apiClient,
  });

  Future<PrivateJournalPagedResponse>
      getMyEntries({
    required int pageNumber,
    required int pageSize,
    String? search,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final queryParameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      queryParameters['search'] =
          normalizedSearch;
    }

    if (fromUtc != null) {
      queryParameters['fromUtc'] =
          fromUtc.toUtc().toIso8601String();
    }

    if (toUtc != null) {
      queryParameters['toUtc'] =
          toUtc.toUtc().toIso8601String();
    }

    final uri = Uri(
      path: '/PrivateJournalEntries/mine',
      queryParameters: queryParameters,
    );

    final response =
        await apiClient.get(uri.toString());

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid '
        'private journal response.',
      );
    }

    return PrivateJournalPagedResponse.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<PrivateJournalEntryModel>
      getById(int id) async {
    final response = await apiClient.get(
      '/PrivateJournalEntries/$id',
    );

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid '
        'private journal entry.',
      );
    }

    return PrivateJournalEntryModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<PrivateJournalEntryModel>
      create(
    CreatePrivateJournalEntryRequest request,
  ) async {
    final response = await apiClient.post(
      '/PrivateJournalEntries',
      body: request.toJson(),
    );

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid '
        'private journal entry.',
      );
    }

    return PrivateJournalEntryModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<PrivateJournalEntryModel>
      update({
    required int id,
    required UpdatePrivateJournalEntryRequest
        request,
  }) async {
    final response = await apiClient.put(
      '/PrivateJournalEntries/$id',
      body: request.toJson(),
    );

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid '
        'private journal entry.',
      );
    }

    return PrivateJournalEntryModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<void> delete(int id) async {
    await apiClient.delete(
      '/PrivateJournalEntries/$id',
    );
  }
}