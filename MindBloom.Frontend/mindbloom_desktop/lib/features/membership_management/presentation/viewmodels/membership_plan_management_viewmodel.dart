import 'package:flutter/material.dart';

import '../../data/models/admin_membership_plan_audit_model.dart';
import '../../data/models/admin_membership_plan_model.dart';
import '../../data/models/membership_plan_request.dart';
import '../../data/repositories/membership_management_repository.dart';

class MembershipPlanManagementViewModel extends ChangeNotifier {
  final MembershipManagementRepository repository;

  MembershipPlanManagementViewModel({required this.repository});

  bool isLoading = false;

  bool isSaving = false;

  String? error;

  List<AdminMembershipPlanModel> plans = [];

  List<AdminMembershipPlanAuditModel> history = [];

  Future<void> loadPlans() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      plans = await repository.getMembershipPlans();
    } catch (exception) {
      error = _cleanError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<AdminMembershipPlanModel?> getPlan(int planId) async {
    try {
      return await repository.getMembershipPlan(planId);
    } catch (exception) {
      error = _cleanError(exception);

      notifyListeners();

      return null;
    }
  }

  Future<bool> createPlan(MembershipPlanRequest request) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.createMembershipPlan(request);

      await _reloadPlans();

      return true;
    } catch (exception) {
      error = _cleanError(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updatePlan({
    required int planId,
    required MembershipPlanRequest request,
  }) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.updateMembershipPlan(planId: planId, request: request);

      await _reloadPlans();

      return true;
    } catch (exception) {
      error = _cleanError(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus({
    required int planId,
    required bool isActive,
    String? reason,
  }) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.updateMembershipPlanStatus(
        planId: planId,
        isActive: isActive,
        reason: reason,
      );

      await _reloadPlans();

      return true;
    } catch (exception) {
      error = _cleanError(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deletePlan(int planId) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    error = null;
    notifyListeners();

    try {
      await repository.deleteMembershipPlan(planId);

      await _reloadPlans();

      return true;
    } catch (exception) {
      error = _cleanError(exception);

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory(int planId) async {
    error = null;
    notifyListeners();

    try {
      history = await repository.getMembershipPlanHistory(planId);
    } catch (exception) {
      history = [];

      error = _cleanError(exception);
    }

    notifyListeners();
  }

  Future<void> _reloadPlans() async {
    plans = await repository.getMembershipPlans();
  }

  String _cleanError(Object exception) {
    var value = exception.toString();

    if (value.startsWith('Exception: ')) {
      value = value.substring('Exception: '.length);
    }

    return value;
  }
}
