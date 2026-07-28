import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/therapist_dashboard_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistDashboardViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  TherapistDashboardViewModel({required this.repository});

  TherapistDashboardModel? dashboard;

  bool isLoading = false;
  String? errorMessage;

  Future<void> loadDashboard() async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      dashboard = await repository.getDashboard();
      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Kontrolnu ploču nije moguće učitati.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadDashboard();

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }
}
