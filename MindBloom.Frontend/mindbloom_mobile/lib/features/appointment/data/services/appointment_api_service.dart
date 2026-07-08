import '../../../../core/network/api_client.dart';
import '../models/appointment_create_request.dart';
import '../models/appointment_model.dart';

class AppointmentApiService {
  final ApiClient apiClient;

  AppointmentApiService({required this.apiClient});

  Future<void> createAppointment(AppointmentCreateRequest request) async {
    await apiClient.post("/Appointments", body: request.toJson());
  }

  Future<List<AppointmentModel>> getMyAppointments() async {
    final response = await apiClient.get('/Appointments/mine');

    return (response as List)
        .map((item) => AppointmentModel.fromJson(item))
        .toList();
  }
}
