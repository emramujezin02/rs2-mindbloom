import '../../../../core/network/api_client.dart';

import '../models/admin_membership_details_model.dart';
import '../models/admin_membership_paged_response.dart';
import '../models/admin_membership_plan_audit_model.dart';
import '../models/admin_membership_plan_model.dart';
import '../models/membership_plan_request.dart';

class MembershipManagementApiService {
  final ApiClient apiClient;

  MembershipManagementApiService({required this.apiClient});

  Future<AdminMembershipPagedResponse> getMemberships({
    String? search,
    int? clientId,
    int? therapistId,
    int? planType,
    String? membershipStatus,
    int? paymentStatus,
    DateTime? expiresFrom,
    DateTime? expiresTo,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final queryParameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      queryParameters['search'] = search.trim();
    }

    if (clientId != null) {
      queryParameters['clientId'] = clientId.toString();
    }

    if (therapistId != null) {
      queryParameters['therapistId'] = therapistId.toString();
    }

    if (planType != null) {
      queryParameters['planType'] = planType.toString();
    }

    if (membershipStatus != null && membershipStatus.trim().isNotEmpty) {
      queryParameters['membershipStatus'] = membershipStatus.trim();
    }

    if (paymentStatus != null) {
      queryParameters['paymentStatus'] = paymentStatus.toString();
    }

    if (expiresFrom != null) {
      queryParameters['expiresFromUtc'] = expiresFrom.toUtc().toIso8601String();
    }

    if (expiresTo != null) {
      queryParameters['expiresToUtc'] = expiresTo.toUtc().toIso8601String();
    }

    final uri = Uri(
      path: '/Admin/memberships',
      queryParameters: queryParameters,
    );

    final response = await apiClient.get(uri.toString());

    return AdminMembershipPagedResponse.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<AdminMembershipDetailsModel> getMembershipDetails(
    int membershipId,
  ) async {
    final response = await apiClient.get('/Admin/memberships/$membershipId');

    return AdminMembershipDetailsModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<List<AdminMembershipPlanModel>> getMembershipPlans() async {
    final response = await apiClient.get('/Admin/membership-plans');

    final rawList = response as List<dynamic>? ?? const [];

    return rawList
        .map(
          (item) => AdminMembershipPlanModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<AdminMembershipPlanModel> getMembershipPlan(int planId) async {
    final response = await apiClient.get('/Admin/membership-plans/$planId');

    return AdminMembershipPlanModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<int> createMembershipPlan(MembershipPlanRequest request) async {
    final response = await apiClient.post(
      '/Admin/membership-plans',
      body: request.toCreateJson(),
    );

    final data = Map<String, dynamic>.from(response as Map);

    return data['id'] is int
        ? data['id'] as int
        : int.tryParse(data['id']?.toString() ?? '') ?? 0;
  }

  Future<void> updateMembershipPlan({
    required int planId,
    required MembershipPlanRequest request,
  }) async {
    await apiClient.put(
      '/Admin/membership-plans/$planId',
      body: request.toUpdateJson(),
    );
  }

  Future<void> updateMembershipPlanStatus({
    required int planId,
    required bool isActive,
    String? reason,
  }) async {
    await apiClient.put(
      '/Admin/membership-plans/'
      '$planId/status',
      body: {'isActive': isActive, 'reason': reason},
    );
  }

  Future<void> deleteMembershipPlan(int planId) async {
    await apiClient.delete('/Admin/membership-plans/$planId');
  }

  Future<List<AdminMembershipPlanAuditModel>> getMembershipPlanHistory(
    int planId,
  ) async {
    final response = await apiClient.get(
      '/Admin/membership-plans/'
      '$planId/history',
    );

    final rawList = response as List<dynamic>? ?? const [];

    return rawList
        .map(
          (item) => AdminMembershipPlanAuditModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
