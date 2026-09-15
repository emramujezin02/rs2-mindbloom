import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/client_dashboard_model.dart';
import '../../data/repositories/client_dashboard_repository.dart';

class ClientDashboardViewModel extends ChangeNotifier {
  final ClientDashboardRepository repository;

  ClientDashboardViewModel({required this.repository});

  bool isLoading = false;
  String? error;
  ClientDashboardModel? dashboard;

  Future<void> loadDashboard() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      dashboard = await repository.getDashboard();
      error = null;
    } catch (exception) {
      error = AppErrorMessage.from(
        exception,
        fallback: 'Početne podatke nije moguće učitati.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadDashboard();

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }
}
