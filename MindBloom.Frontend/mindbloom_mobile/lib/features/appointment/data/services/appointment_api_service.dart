import '../../../../core/network/api_client.dart';
import '../models/appointment_create_request.dart';

class AppointmentApiService {
  final ApiClient apiClient;

  AppointmentApiService({required this.apiClient});

  Future<void> createAppointment(AppointmentCreateRequest request) async {
    await apiClient.post("/Appointments", body: request.toJson());
  }
}
