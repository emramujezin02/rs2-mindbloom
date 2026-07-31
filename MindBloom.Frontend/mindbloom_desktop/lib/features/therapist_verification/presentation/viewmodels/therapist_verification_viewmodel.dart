import 'package:flutter/foundation.dart';

import '../../data/models/therapist_verification_list_model.dart';
import '../../data/repositories/therapist_verification_repository.dart';

class TherapistVerificationViewModel extends ChangeNotifier {
  final TherapistVerificationRepository repository;

  TherapistVerificationViewModel({required this.repository});

  bool isLoading = false;
  String? errorMessage;

  List<TherapistVerificationListModel> therapists = [];

  int pageNumber = 1;
  int pageSize = 10;
  int totalCount = 0;
  int totalPages = 0;

  String search = '';
  String? status = 'Pending';

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> load({
    int? page,
    String? searchValue,
    String? statusValue,
    bool changeStatus = false,
  }) async {
    if (isLoading) {
      return;
    }

    if (searchValue != null) {
      search = searchValue.trim();
    }

    if (changeStatus) {
      status = statusValue?.trim().isEmpty == true ? null : statusValue;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.getPendingTherapists(
        pageNumber: page ?? pageNumber,
        pageSize: pageSize,
        search: search,
        status: status,
      );

      therapists = result.items;
      pageNumber = result.pageNumber;
      pageSize = result.pageSize;
      totalCount = result.totalCount;
      totalPages = result.totalPages;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> filterByStatus(String? value) {
    return load(page: 1, statusValue: value, changeStatus: true);
  }

  Future<void> searchTherapists(String value) {
    return load(page: 1, searchValue: value);
  }

  Future<void> clearSearch() {
    return load(page: 1, searchValue: '');
  }

  Future<void> previousPage() {
    if (!hasPreviousPage) {
      return Future.value();
    }

    return load(page: pageNumber - 1);
  }

  Future<void> nextPage() {
    if (!hasNextPage) {
      return Future.value();
    }

    return load(page: pageNumber + 1);
  }
}
