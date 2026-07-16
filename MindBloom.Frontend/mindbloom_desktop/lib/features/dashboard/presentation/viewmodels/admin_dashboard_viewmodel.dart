import 'package:flutter/foundation.dart';
import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';
import '../../data/repositories/admin_dashboard_repository.dart';

class AdminDashboardViewModel extends ChangeNotifier {
  final AdminDashboardRepository repository;

  AdminDashboardViewModel({required this.repository});

  bool isLoading = false;

  String? errorMessage;

  AdminDashboardModel? dashboard;

  Future<void> loadDashboard() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      dashboard = await repository.getDashboard();
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

  String _cleanError(Object error) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    return value;
  }
}
