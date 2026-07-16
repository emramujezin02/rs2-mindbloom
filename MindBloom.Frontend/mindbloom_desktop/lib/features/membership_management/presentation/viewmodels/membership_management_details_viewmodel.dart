import 'package:flutter/material.dart';

import '../../data/models/admin_membership_details_model.dart';
import '../../data/repositories/membership_management_repository.dart';

class MembershipManagementDetailsViewModel extends ChangeNotifier {
  final MembershipManagementRepository repository;

  MembershipManagementDetailsViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  AdminMembershipDetailsModel? membership;

  Future<void> loadMembership(int membershipId) async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      membership = await repository.getMembershipDetails(membershipId);
    } catch (exception) {
      error = exception.toString();
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }
}
