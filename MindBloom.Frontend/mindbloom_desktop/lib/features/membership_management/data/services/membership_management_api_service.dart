import '../../../../core/network/api_client.dart';
import '../models/admin_membership_details_model.dart';
import '../models/admin_membership_paged_response.dart';

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

    final uri = Uri(
      path: '/Admin/memberships',
      queryParameters: queryParameters,
    );

    final response = await apiClient.get(uri.toString());

    return AdminMembershipPagedResponse.fromJson(
      response as Map<String, dynamic>,
    );
  }

  Future<AdminMembershipDetailsModel> getMembershipDetails(
    int membershipId,
  ) async {
    final response = await apiClient.get('/Admin/memberships/$membershipId');

    return AdminMembershipDetailsModel.fromJson(
      response as Map<String, dynamic>,
    );
  }
}
