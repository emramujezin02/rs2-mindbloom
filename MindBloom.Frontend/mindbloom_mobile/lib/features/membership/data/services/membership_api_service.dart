import '../../../../core/network/api_client.dart';
import '../models/confirm_membership_payment_request.dart';
import '../models/membership_model.dart';
import '../models/membership_payment_intent_response.dart';
import '../models/membership_plan_model.dart';
import '../models/membership_receipt_model.dart';
import '../models/purchase_membership_request.dart';
import '../models/use_membership_request.dart';
import '../../../../core/network/idempotency_key_generator.dart';

class MembershipApiService {
  final ApiClient apiClient;

  MembershipApiService({required this.apiClient});

  Future<List<MembershipPlanModel>> getPlansForTherapist(
    int therapistId,
  ) async {
    final response = await apiClient.get(
      '/Memberships/therapist/'
      '$therapistId/plans',
      requiresAuth: false,
    );

    if (response is! List) {
      return [];
    }

    return response
        .whereType<Map>()
        .map(
          (item) =>
              MembershipPlanModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((plan) => plan.isActive)
        .toList();
  }

  Future<MembershipPaymentIntentResponse> createPaymentIntent(
    PurchaseMembershipRequest request, {
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? IdempotencyKeyGenerator.generate();

    final response = await apiClient.post(
      '/Memberships/create-payment-intent',
      body: request.toJson(),
      idempotencyKey: key,
    );

    return MembershipPaymentIntentResponse.fromJson(
      response as Map<String, dynamic>,
    );
  }

  Future<MembershipModel> confirmPayment(
    ConfirmMembershipPaymentRequest request, {
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? IdempotencyKeyGenerator.generate();

    final response = await apiClient.post(
      '/Memberships/confirm-payment',
      body: request.toJson(),
      idempotencyKey: key,
    );

    return MembershipModel.fromJson(response as Map<String, dynamic>);
  }

  Future<List<MembershipModel>> getMyMemberships() async {
    final response = await apiClient.get('/Memberships/mine');

    return (response as List)
        .map((item) => MembershipModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MembershipReceiptModel> getReceipt(int membershipId) async {
    final response = await apiClient.get('/Memberships/$membershipId/receipt');

    return MembershipReceiptModel.fromJson(response as Map<String, dynamic>);
  }

  Future<void> useMembership(UseMembershipRequest request) async {
    await apiClient.post('/Memberships/use', body: request.toJson());
  }
}
