import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../core/error/app_exception.dart';
import '../../data/models/membership_model.dart';
import '../../data/models/membership_plan_model.dart';
import '../../data/models/membership_receipt_model.dart';
import '../../data/models/purchase_membership_request.dart';
import '../../data/models/use_membership_request.dart';
import '../../data/repositories/membership_repository.dart';

class MembershipViewModel extends ChangeNotifier {
  final MembershipRepository repository;

  MembershipViewModel({required this.repository});

  bool isLoading = false;

  bool isPurchasing = false;

  String? error;

  List<MembershipModel> memberships = [];

  List<MembershipPlanModel> plans = [];

  List<MembershipModel> get activeMemberships {
    return memberships
        .where(
          (membership) =>
              membership.isActive &&
              membership.isPaid &&
              !membership.isExpired &&
              membership.remainingSessions > 0,
        )
        .toList();
  }

  List<MembershipModel> get membershipHistory {
    return memberships
        .where(
          (membership) =>
              !activeMemberships.any((active) => active.id == membership.id),
        )
        .toList();
  }

  Future<void> loadMyMemberships() async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    error = null;

    notifyListeners();

    try {
      memberships = await repository.getMyMemberships();
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> loadPlans(int therapistId) async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    error = null;

    notifyListeners();

    try {
      final result = await repository.getPlansForTherapist(therapistId);

      plans = result.where((plan) => plan.isActive).toList();
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> purchaseMembership({
    required int therapistId,
    required int planType,
  }) async {
    if (isPurchasing) {
      return false;
    }

    isPurchasing = true;

    error = null;

    notifyListeners();

    try {
      final paymentIntent = await repository.createPaymentIntent(
        PurchaseMembershipRequest(therapistId: therapistId, planType: planType),
      );

      if (paymentIntent.clientSecret.trim().isEmpty) {
        throw const AppException(
          message: 'Stripe client secret was not returned.',
        );
      }

      if (paymentIntent.paymentIntentId.trim().isEmpty) {
        throw const AppException(
          message: 'Stripe PaymentIntent ID was not returned.',
        );
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent.clientSecret,
          merchantDisplayName: 'MindBloom',
          style: ThemeMode.system,
          primaryButtonLabel: 'Purchase membership',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final membership = await repository.confirmPayment(
        paymentIntent.paymentIntentId,
      );

      memberships.removeWhere((item) => item.id == membership.id);

      memberships.insert(0, membership);

      return membership.isPaid && membership.isActive;
    } on StripeException catch (exception) {
      error =
          exception.error.localizedMessage ??
          'Stripe payment was cancelled or could not be completed.';

      return false;
    } catch (exception) {
      error = _normalizeError(exception);

      return false;
    } finally {
      isPurchasing = false;

      notifyListeners();
    }
  }

  Future<MembershipReceiptModel> getReceipt(int membershipId) {
    return repository.getReceipt(membershipId);
  }

  Future<bool> useMembership({required int appointmentId}) async {
    if (isLoading) {
      return false;
    }

    isLoading = true;

    error = null;

    notifyListeners();

    try {
      await repository.useMembership(
        UseMembershipRequest(appointmentId: appointmentId),
      );

      return true;
    } catch (exception) {
      error = _normalizeError(exception);

      return false;
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  String _normalizeError(Object exception) {
    if (exception is AppException) {
      return exception.message;
    }

    return exception.toString().replaceFirst('Exception: ', '').trim();
  }
}
