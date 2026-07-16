import 'package:flutter/foundation.dart';

import '../../data/models/admin_appointment_model.dart';
import '../../data/repositories/appointment_management_repository.dart';

class AppointmentManagementViewModel extends ChangeNotifier {
  final AppointmentManagementRepository repository;

  AppointmentManagementViewModel({required this.repository});

  bool isLoading = false;

  String? error;

  List<AdminAppointmentModel> appointments = [];

  int pageNumber = 1;

  final int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String? currentSearch;

  String? currentStatus;

  String? currentType;

  DateTime? currentDateFrom;

  DateTime? currentDateTo;

  bool? currentIsPaid;

  Future<void> load({
    int requestedPage = 1,
    String? search,
    String? status,
    String? type,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? isPaid,
  }) async {
    isLoading = true;
    error = null;

    currentSearch = search;
    currentStatus = status;
    currentType = type;
    currentDateFrom = dateFrom;
    currentDateTo = dateTo;
    currentIsPaid = isPaid;

    notifyListeners();

    try {
      final response = await repository.getAppointments(
        pageNumber: requestedPage,
        pageSize: pageSize,
        search: search,
        status: status,
        type: type,
        dateFrom: dateFrom,
        dateTo: dateTo,
        isPaid: isPaid,
      );

      appointments = response.items;
      pageNumber = response.pageNumber;
      totalCount = response.totalCount;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> reload() {
    return load(
      requestedPage: pageNumber,
      search: currentSearch,
      status: currentStatus,
      type: currentType,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      isPaid: currentIsPaid,
    );
  }

  Future<void> nextPage() async {
    if (pageNumber >= totalPages || isLoading) {
      return;
    }

    await load(
      requestedPage: pageNumber + 1,
      search: currentSearch,
      status: currentStatus,
      type: currentType,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      isPaid: currentIsPaid,
    );
  }

  Future<void> previousPage() async {
    if (pageNumber <= 1 || isLoading) {
      return;
    }

    await load(
      requestedPage: pageNumber - 1,
      search: currentSearch,
      status: currentStatus,
      type: currentType,
      dateFrom: currentDateFrom,
      dateTo: currentDateTo,
      isPaid: currentIsPaid,
    );
  }
}
