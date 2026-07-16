import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';
import '../../../../core/network/api_client.dart';

class AdminDashboardApiService {
  final ApiClient apiClient;

  AdminDashboardApiService({required this.apiClient});

  Future<AdminDashboardModel> getDashboard() async {
    final response = await apiClient.get('/Admin/dashboard');

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid dashboard data.');
    }

    return AdminDashboardModel.fromJson(response);
  }
}
