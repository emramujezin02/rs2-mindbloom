import '../../../../core/network/api_client.dart';
import '../models/membership_model.dart';
import '../models/membership_plan_model.dart';
import '../models/purchase_membership_request.dart';
import '../models/use_membership_request.dart';

class MembershipApiService {
  final ApiClient apiClient;

  MembershipApiService({required this.apiClient});

  Future<List<MembershipPlanModel>> getPlansForTherapist(
    int therapistId,
  ) async {
    final response = await apiClient.get(
      '/Memberships/therapist/$therapistId/plans',
    );

    return (response as List)
        .map((item) => MembershipPlanModel.fromJson(item))
        .toList();
  }

  Future<MembershipModel> purchaseMembership(
    PurchaseMembershipRequest request,
  ) async {
    final response = await apiClient.post(
      '/Memberships/purchase',
      body: request.toJson(),
    );

    return MembershipModel.fromJson(response);
  }

  Future<List<MembershipModel>> getMyMemberships() async {
    final response = await apiClient.get('/Memberships/mine');

    return (response as List)
        .map((item) => MembershipModel.fromJson(item))
        .toList();
  }

  Future<void> useMembership(UseMembershipRequest request) async {
    await apiClient.post('/Memberships/use', body: request.toJson());
  }
}
