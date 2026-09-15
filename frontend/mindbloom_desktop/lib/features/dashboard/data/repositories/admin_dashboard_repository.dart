import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';

import '../services/admin_dashboard_api_service.dart';

class AdminDashboardRepository {
  final AdminDashboardApiService apiService;

  AdminDashboardRepository({required this.apiService});

  Future<AdminDashboardModel> getDashboard({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) {
    return apiService.getDashboard(fromUtc: fromUtc, toUtc: toUtc);
  }
}
