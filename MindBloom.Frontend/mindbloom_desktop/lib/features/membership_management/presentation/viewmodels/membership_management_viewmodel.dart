import 'package:flutter/material.dart';

import '../../data/models/admin_membership_model.dart';
import '../../data/repositories/membership_management_repository.dart';

class MembershipManagementViewModel extends ChangeNotifier {
  final MembershipManagementRepository repository;

  MembershipManagementViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  List<AdminMembershipModel> memberships = [];

  String search = '';

  int? planType;

  String? membershipStatus;

  int? paymentStatus;

  DateTime? expiresFrom;

  DateTime? expiresTo;

  int pageNumber = 1;

  final int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> loadMemberships({bool resetPage = false}) async {
    if (resetPage) {
      pageNumber = 1;
    }

    isLoading = true;
    error = null;

    notifyListeners();

    try {
      final result = await repository.getMemberships(
        search: search,
        planType: planType,
        membershipStatus: membershipStatus,
        paymentStatus: paymentStatus,
        expiresFrom: expiresFrom,
        expiresTo: expiresTo,
        pageNumber: pageNumber,
        pageSize: pageSize,
      );

      memberships = result.items;

      pageNumber = result.pageNumber;

      totalCount = result.totalCount;

      totalPages = result.totalPages;
    } catch (exception) {
      error = _cleanError(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> applySearch(String value) async {
    search = value.trim();

    await loadMemberships(resetPage: true);
  }

  Future<void> setPlanType(int? value) async {
    planType = value;

    await loadMemberships(resetPage: true);
  }

  Future<void> setMembershipStatus(String? value) async {
    membershipStatus = value;

    await loadMemberships(resetPage: true);
  }

  Future<void> setPaymentStatus(int? value) async {
    paymentStatus = value;

    await loadMemberships(resetPage: true);
  }

  Future<void> setExpirationRange({DateTime? from, DateTime? to}) async {
    expiresFrom = from;

    expiresTo = to;

    await loadMemberships(resetPage: true);
  }

  Future<void> clearFilters() async {
    search = '';
    planType = null;
    membershipStatus = null;
    paymentStatus = null;
    expiresFrom = null;
    expiresTo = null;

    await loadMemberships(resetPage: true);
  }

  Future<void> nextPage() async {
    if (!hasNextPage || isLoading) {
      return;
    }

    pageNumber++;

    await loadMemberships();
  }

  Future<void> previousPage() async {
    if (!hasPreviousPage || isLoading) {
      return;
    }

    pageNumber--;

    await loadMemberships();
  }

  Future<void> refresh() {
    return loadMemberships();
  }

  String _cleanError(Object exception) {
    var value = exception.toString();

    if (value.startsWith('Exception: ')) {
      value = value.substring('Exception: '.length);
    }

    return value;
  }
}
