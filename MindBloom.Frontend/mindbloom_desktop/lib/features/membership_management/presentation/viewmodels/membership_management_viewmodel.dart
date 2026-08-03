import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/error/app_error_helper.dart';
import '../../data/models/admin_membership_model.dart';
import '../../data/repositories/membership_management_repository.dart';

class MembershipManagementViewModel extends ChangeNotifier {
  final MembershipManagementRepository repository;

  MembershipManagementViewModel({required this.repository});

  Timer? _searchDebounce;

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

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  bool get hasPreviousPage {
    return pageNumber > 1;
  }

  bool get hasNextPage {
    return pageNumber < totalPages;
  }

  Future<void> loadMemberships({
    bool resetPage = false,
    bool clearCurrentResults = false,
  }) async {
    if (isLoading) {
      return;
    }

    if (resetPage) {
      pageNumber = 1;
    }

    isLoading = true;
    error = null;

    if (clearCurrentResults) {
      memberships = [];
      totalCount = 0;
      totalPages = 0;
    }

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

      pageNumber = result.pageNumber == 0 ? 1 : result.pageNumber;

      pageSize = result.pageSize == 0 ? pageSize : result.pageSize;

      totalCount = result.totalCount;
      totalPages = result.totalPages;
    } catch (exception) {
      memberships = [];
      totalCount = 0;
      totalPages = 0;

      error = AppErrorHelper.message(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void updateSearch(String value) {
    search = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      loadMemberships(resetPage: true, clearCurrentResults: true);
    });
  }

  Future<void> applySearch(String value) async {
    _searchDebounce?.cancel();

    search = value.trim();

    await loadMemberships(resetPage: true, clearCurrentResults: true);
  }

  Future<void> setPlanType(int? value) async {
    planType = value;

    await loadMemberships(resetPage: true, clearCurrentResults: true);
  }

  Future<void> setMembershipStatus(String? value) async {
    membershipStatus = value;

    await loadMemberships(resetPage: true, clearCurrentResults: true);
  }

  Future<void> setPaymentStatus(int? value) async {
    paymentStatus = value;

    await loadMemberships(resetPage: true, clearCurrentResults: true);
  }

  Future<void> setExpirationRange({DateTime? from, DateTime? to}) async {
    expiresFrom = from;
    expiresTo = to;

    await loadMemberships(resetPage: true, clearCurrentResults: true);
  }

  Future<void> clearFilters() async {
    _searchDebounce?.cancel();

    search = '';
    planType = null;
    membershipStatus = null;
    paymentStatus = null;
    expiresFrom = null;
    expiresTo = null;

    await loadMemberships(resetPage: true, clearCurrentResults: true);
  }

  Future<void> changePageSize(int value) async {
    if (value == pageSize) {
      return;
    }

    pageSize = value;

    await loadMemberships(resetPage: true, clearCurrentResults: true);
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

  void clearError() {
    if (error == null) {
      return;
    }

    error = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
