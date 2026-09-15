import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/widgets/app_error_message.dart';
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
  bool isUsingMembership = false;

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
    final activeIds = activeMemberships
        .map((membership) => membership.id)
        .toSet();

    return memberships
        .where((membership) => !activeIds.contains(membership.id))
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
      final loadedMemberships = await repository.getMyMemberships();

      memberships = loadedMemberships;
      error = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
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
      final loadedPlans = await repository.getPlansForTherapist(therapistId);

      plans = loadedPlans.where((plan) => plan.isActive).toList();

      error = null;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
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

      error = null;

      return membership.isPaid && membership.isActive;
    } on StripeException catch (exception) {
      error = exception.error.localizedMessage?.trim();

      if (error == null || error!.isEmpty) {
        error = 'Stripe payment was cancelled or could not be completed.';
      }

      return false;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
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
    if (isUsingMembership) {
      return false;
    }

    isUsingMembership = true;
    error = null;
    notifyListeners();

    try {
      await repository.useMembership(
        UseMembershipRequest(appointmentId: appointmentId),
      );

      error = null;
      return true;
    } catch (exception) {
      error = AppErrorMessage.from(exception);
      return false;
    } finally {
      isUsingMembership = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;
    notifyListeners();
  }
}
