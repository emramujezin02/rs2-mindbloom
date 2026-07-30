import 'package:flutter/foundation.dart';
import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';

import '../../data/repositories/admin_dashboard_repository.dart';

enum AdminDashboardPeriod {
  last30Days,
  last3Months,
  last6Months,
  currentYear,
  custom,
}

extension AdminDashboardPeriodExtension on AdminDashboardPeriod {
  String get label {
    switch (this) {
      case AdminDashboardPeriod.last30Days:
        return 'Last 30 days';

      case AdminDashboardPeriod.last3Months:
        return 'Last 3 months';

      case AdminDashboardPeriod.last6Months:
        return 'Last 6 months';

      case AdminDashboardPeriod.currentYear:
        return 'Current year';

      case AdminDashboardPeriod.custom:
        return 'Custom period';
    }
  }
}

class AdminDashboardViewModel extends ChangeNotifier {
  final AdminDashboardRepository repository;

  AdminDashboardViewModel({required this.repository}) {
    _applyPresetPeriod(AdminDashboardPeriod.last6Months, notify: false);
  }

  bool isLoading = false;

  String? errorMessage;

  AdminDashboardModel? dashboard;

  AdminDashboardPeriod selectedPeriod = AdminDashboardPeriod.last6Months;

  late DateTime fromDate;

  late DateTime toDate;

  Future<void> loadDashboard() async {
    if (isLoading) {
      return;
    }

    if (fromDate.isAfter(toDate)) {
      errorMessage = 'The start date cannot be later than the end date.';

      notifyListeners();

      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      dashboard = await repository.getDashboard(
        fromUtc: _startOfDayUtc(fromDate),
        toUtc: _endOfDayUtc(toDate),
      );
    } catch (error) {
      errorMessage = _cleanError(error);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<void> refreshDashboard() {
    return loadDashboard();
  }

  Future<void> setPeriod(AdminDashboardPeriod period) async {
    if (period == AdminDashboardPeriod.custom) {
      selectedPeriod = period;

      notifyListeners();

      return;
    }

    _applyPresetPeriod(period);

    await loadDashboard();
  }

  void setCustomFromDate(DateTime value) {
    selectedPeriod = AdminDashboardPeriod.custom;

    fromDate = DateTime(value.year, value.month, value.day);

    errorMessage = null;

    notifyListeners();
  }

  void setCustomToDate(DateTime value) {
    selectedPeriod = AdminDashboardPeriod.custom;

    toDate = DateTime(value.year, value.month, value.day);

    errorMessage = null;

    notifyListeners();
  }

  void _applyPresetPeriod(AdminDashboardPeriod period, {bool notify = true}) {
    final now = DateTime.now();

    selectedPeriod = period;

    toDate = DateTime(now.year, now.month, now.day);

    switch (period) {
      case AdminDashboardPeriod.last30Days:
        fromDate = toDate.subtract(const Duration(days: 29));

      case AdminDashboardPeriod.last3Months:
        fromDate = DateTime(now.year, now.month - 2, 1);

      case AdminDashboardPeriod.last6Months:
        fromDate = DateTime(now.year, now.month - 5, 1);

      case AdminDashboardPeriod.currentYear:
        fromDate = DateTime(now.year, 1, 1);

      case AdminDashboardPeriod.custom:
        break;
    }

    errorMessage = null;

    if (notify) {
      notifyListeners();
    }
  }

  DateTime _startOfDayUtc(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day);
  }

  DateTime _endOfDayUtc(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  String _cleanError(Object error) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }
}
