import 'package:flutter/material.dart';

import '../../data/models/client_dashboard_model.dart';
import '../../data/repositories/client_dashboard_repository.dart';

class ClientDashboardViewModel extends ChangeNotifier {
  final ClientDashboardRepository repository;

  ClientDashboardViewModel({required this.repository});

  bool isLoading = false;
  String? error;
  ClientDashboardModel? dashboard;

  Future<void> loadDashboard() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      dashboard = await repository.getDashboard();
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
