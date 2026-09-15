import '../../../../core/network/api_client.dart';
import '../models/client_dashboard_model.dart';

class ClientDashboardApiService {
  final ApiClient apiClient;

  ClientDashboardApiService({required this.apiClient});

  Future<ClientDashboardModel> getDashboard() async {
    final response = await apiClient.get('/Appointments/client-dashboard');

    return ClientDashboardModel.fromJson(response);
  }
}
