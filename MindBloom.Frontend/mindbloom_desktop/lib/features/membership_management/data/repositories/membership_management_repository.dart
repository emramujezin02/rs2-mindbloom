import '../models/admin_membership_details_model.dart';
import '../models/admin_membership_paged_response.dart';
import '../models/admin_membership_plan_audit_model.dart';
import '../models/admin_membership_plan_model.dart';
import '../models/membership_plan_request.dart';
import '../services/membership_management_api_service.dart';

class MembershipManagementRepository {
  final MembershipManagementApiService apiService;

  MembershipManagementRepository({required this.apiService});

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
  }) {
    return apiService.getMemberships(
      search: search,
      clientId: clientId,
      therapistId: therapistId,
      planType: planType,
      membershipStatus: membershipStatus,
      paymentStatus: paymentStatus,
      expiresFrom: expiresFrom,
      expiresTo: expiresTo,
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<AdminMembershipDetailsModel> getMembershipDetails(int membershipId) {
    return apiService.getMembershipDetails(membershipId);
  }

  Future<List<AdminMembershipPlanModel>> getMembershipPlans() {
    return apiService.getMembershipPlans();
  }

  Future<AdminMembershipPlanModel> getMembershipPlan(int planId) {
    return apiService.getMembershipPlan(planId);
  }

  Future<int> createMembershipPlan(MembershipPlanRequest request) {
    return apiService.createMembershipPlan(request);
  }

  Future<void> updateMembershipPlan({
    required int planId,
    required MembershipPlanRequest request,
  }) {
    return apiService.updateMembershipPlan(planId: planId, request: request);
  }

  Future<void> updateMembershipPlanStatus({
    required int planId,
    required bool isActive,
    String? reason,
  }) {
    return apiService.updateMembershipPlanStatus(
      planId: planId,
      isActive: isActive,
      reason: reason,
    );
  }

  Future<void> deleteMembershipPlan(int planId) {
    return apiService.deleteMembershipPlan(planId);
  }

  Future<List<AdminMembershipPlanAuditModel>> getMembershipPlanHistory(
    int planId,
  ) {
    return apiService.getMembershipPlanHistory(planId);
  }
}
