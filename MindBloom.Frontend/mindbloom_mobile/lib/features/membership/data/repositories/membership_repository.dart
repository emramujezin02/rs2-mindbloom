import '../models/confirm_membership_payment_request.dart';
import '../models/membership_model.dart';
import '../models/membership_payment_intent_response.dart';
import '../models/membership_plan_model.dart';
import '../models/membership_receipt_model.dart';
import '../models/purchase_membership_request.dart';
import '../models/use_membership_request.dart';
import '../services/membership_api_service.dart';

class MembershipRepository {
  final MembershipApiService apiService;

  MembershipRepository({required this.apiService});

  Future<List<MembershipPlanModel>> getPlansForTherapist(int therapistId) {
    return apiService.getPlansForTherapist(therapistId);
  }

  Future<MembershipPaymentIntentResponse> createPaymentIntent(
    PurchaseMembershipRequest request,
  ) {
    return apiService.createPaymentIntent(request);
  }

  Future<MembershipModel> confirmPayment(String paymentIntentId) {
    return apiService.confirmPayment(
      ConfirmMembershipPaymentRequest(paymentIntentId: paymentIntentId),
    );
  }

  Future<List<MembershipModel>> getMyMemberships() {
    return apiService.getMyMemberships();
  }

  Future<MembershipReceiptModel> getReceipt(int membershipId) {
    return apiService.getReceipt(membershipId);
  }

  Future<void> useMembership(UseMembershipRequest request) {
    return apiService.useMembership(request);
  }
}
