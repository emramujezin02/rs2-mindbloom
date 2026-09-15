import '../models/confirm_membership_payment_request.dart';
import '../models/membership_model.dart';
import '../models/membership_payment_intent_response.dart';
import '../models/membership_plan_model.dart';
import '../models/membership_receipt_model.dart';
import '../models/purchase_membership_request.dart';
import '../models/use_membership_request.dart';
import '../services/membership_api_service.dart';
import 'dart:convert';

import '../../../../core/network/idempotency_key_generator.dart';

class MembershipRepository {
  final MembershipApiService apiService;
  final Map<String, String> _membershipPurchaseKeys = <String, String>{};

  final Map<String, String> _membershipConfirmationKeys = <String, String>{};

  MembershipRepository({required this.apiService});

  Future<List<MembershipPlanModel>> getPlansForTherapist(int therapistId) {
    return apiService.getPlansForTherapist(therapistId);
  }

  Future<MembershipPaymentIntentResponse> createPaymentIntent(
    PurchaseMembershipRequest request,
  ) async {
    final operationKey = jsonEncode(request.toJson());

    final idempotencyKey = _membershipPurchaseKeys.putIfAbsent(
      operationKey,
      IdempotencyKeyGenerator.generate,
    );

    try {
      final result = await apiService.createPaymentIntent(
        request,
        idempotencyKey: idempotencyKey,
      );

      _membershipPurchaseKeys.remove(operationKey);

      return result;
    } catch (_) {
      rethrow;
    }
  }

  Future<MembershipModel> confirmPayment(String paymentIntentId) async {
    final idempotencyKey = _membershipConfirmationKeys.putIfAbsent(
      paymentIntentId,
      IdempotencyKeyGenerator.generate,
    );

    try {
      final result = await apiService.confirmPayment(
        ConfirmMembershipPaymentRequest(paymentIntentId: paymentIntentId),
        idempotencyKey: idempotencyKey,
      );

      _membershipConfirmationKeys.remove(paymentIntentId);

      return result;
    } catch (_) {
      rethrow;
    }
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
