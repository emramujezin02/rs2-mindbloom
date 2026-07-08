import '../models/client_dashboard_model.dart';
import '../services/client_dashboard_api_service.dart';

class ClientDashboardRepository {
  final ClientDashboardApiService apiService;

  ClientDashboardRepository({required this.apiService});

  Future<ClientDashboardModel> getDashboard() {
    return apiService.getDashboard();
  }
}
