import '../models/membership_model.dart';
import '../models/membership_plan_model.dart';
import '../models/purchase_membership_request.dart';
import '../models/use_membership_request.dart';
import '../services/membership_api_service.dart';

class MembershipRepository {
  final MembershipApiService apiService;

  MembershipRepository({required this.apiService});

  Future<List<MembershipPlanModel>> getPlansForTherapist(int therapistId) {
    return apiService.getPlansForTherapist(therapistId);
  }

  Future<MembershipModel> purchaseMembership(
    PurchaseMembershipRequest request,
  ) {
    return apiService.purchaseMembership(request);
  }

  Future<List<MembershipModel>> getMyMemberships() {
    return apiService.getMyMemberships();
  }

  Future<void> useMembership(UseMembershipRequest request) {
    return apiService.useMembership(request);
  }
}
