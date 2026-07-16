import '../models/admin_membership_details_model.dart';
import '../models/admin_membership_paged_response.dart';
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
      pageNumber: pageNumber,
      pageSize: pageSize,
    );
  }

  Future<AdminMembershipDetailsModel> getMembershipDetails(int membershipId) {
    return apiService.getMembershipDetails(membershipId);
  }
}
