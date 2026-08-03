import '../../../../core/network/api_client.dart';
import '../models/admin_audit_filter_options_model.dart';
import '../models/admin_audit_paged_response.dart';

class AdminAuditApiService {
  final ApiClient apiClient;

  const AdminAuditApiService({required this.apiClient});

  Future<AdminAuditPagedResponse> getAuditLogs({
    required int pageNumber,
    required int pageSize,
    String? search,
    int? adminUserId,
    String? action,
    String? entityType,
    DateTime? fromUtc,
    DateTime? toUtc,
    bool? isSuccessful,
  }) async {
    final query = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      query['search'] = normalizedSearch;
    }

    if (adminUserId != null) {
      query['adminUserId'] = adminUserId.toString();
    }

    if (action != null && action.trim().isNotEmpty) {
      query['action'] = action.trim();
    }

    if (entityType != null && entityType.trim().isNotEmpty) {
      query['entityType'] = entityType.trim();
    }

    if (fromUtc != null) {
      query['fromUtc'] = fromUtc.toUtc().toIso8601String();
    }

    if (toUtc != null) {
      query['toUtc'] = toUtc.toUtc().toIso8601String();
    }

    if (isSuccessful != null) {
      query['isSuccessful'] = isSuccessful.toString();
    }

    final queryString = Uri(queryParameters: query).query;

    final response = await apiClient.get('/api/admin/audit-logs?$queryString');

    if (response is! Map) {
      throw const FormatException('Server je vratio neispravan audit odgovor.');
    }

    return AdminAuditPagedResponse.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<AdminAuditFilterOptionsModel> getFilterOptions() async {
    final response = await apiClient.get(
      '/api/admin/audit-logs/filter-options',
    );

    if (response is! Map) {
      throw const FormatException('Server je vratio neispravne audit filtere.');
    }

    return AdminAuditFilterOptionsModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
