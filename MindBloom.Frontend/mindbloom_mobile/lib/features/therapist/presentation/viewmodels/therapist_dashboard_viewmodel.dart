import 'package:flutter/foundation.dart';

import '../../data/models/therapist_dashboard_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistDashboardViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  TherapistDashboardViewModel({required this.repository});

  TherapistDashboardModel? dashboard;

  bool isLoading = false;
  String? errorMessage;

  Future<void> loadDashboard() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      dashboard = await repository.getDashboard();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await loadDashboard();
  }
}
