import '../models/admin_audit_filter_options_model.dart';
import '../models/admin_audit_paged_response.dart';
import '../services/admin_audit_api_service.dart';

class AdminAuditRepository {
  final AdminAuditApiService apiService;

  const AdminAuditRepository({required this.apiService});

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
  }) {
    return apiService.getAuditLogs(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      adminUserId: adminUserId,
      action: action,
      entityType: entityType,
      fromUtc: fromUtc,
      toUtc: toUtc,
      isSuccessful: isSuccessful,
    );
  }

  Future<AdminAuditFilterOptionsModel> getFilterOptions() {
    return apiService.getFilterOptions();
  }
}
