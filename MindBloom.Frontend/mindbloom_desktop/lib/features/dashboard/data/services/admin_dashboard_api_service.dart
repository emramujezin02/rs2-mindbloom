import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';

import '../../../../core/network/api_client.dart';

class AdminDashboardApiService {
  final ApiClient apiClient;

  AdminDashboardApiService({required this.apiClient});

  Future<AdminDashboardModel> getDashboard({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) async {
    final fromValue = Uri.encodeQueryComponent(
      fromUtc.toUtc().toIso8601String(),
    );

    final toValue = Uri.encodeQueryComponent(toUtc.toUtc().toIso8601String());

    final response = await apiClient.get(
      '/admin/reports/dashboard'
      '?fromUtc=$fromValue'
      '&toUtc=$toValue',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid dashboard data.');
    }

    return AdminDashboardModel.fromJson(response);
  }
}
