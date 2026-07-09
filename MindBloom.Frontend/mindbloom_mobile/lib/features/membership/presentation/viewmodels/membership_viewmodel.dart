import 'package:flutter/material.dart';

import '../../data/models/membership_model.dart';
import '../../data/models/membership_plan_model.dart';
import '../../data/models/purchase_membership_request.dart';
import '../../data/models/use_membership_request.dart';
import '../../data/repositories/membership_repository.dart';

class MembershipViewModel extends ChangeNotifier {
  final MembershipRepository repository;

  MembershipViewModel({required this.repository});

  bool isLoading = false;
  String? error;

  List<MembershipModel> memberships = [];
  List<MembershipPlanModel> plans = [];

  Future<void> loadMyMemberships() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      memberships = await repository.getMyMemberships();
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadPlans(int therapistId) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      plans = await repository.getPlansForTherapist(therapistId);
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> purchaseMembership({
    required int therapistId,
    required int planType,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await repository.purchaseMembership(
        PurchaseMembershipRequest(therapistId: therapistId, planType: planType),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();

      return false;
    }
  }

  Future<bool> useMembership({required int appointmentId}) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await repository.useMembership(
        UseMembershipRequest(appointmentId: appointmentId),
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();

      return false;
    }
  }
}
