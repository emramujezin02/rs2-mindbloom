import '../../../../core/network/api_client.dart';
import '../models/appointment_create_request.dart';
import '../models/appointment_model.dart';
import '../models/cancel_appointment_request.dart';

class AppointmentApiService {
  final ApiClient apiClient;

  AppointmentApiService({required this.apiClient});

  Future<void> createAppointment(AppointmentCreateRequest request) async {
    await apiClient.post('/Appointments', body: request.toJson());
  }

  Future<List<AppointmentModel>> getMyAppointments() async {
    final response = await apiClient.get('/Appointments/mine');

    return (response as List)
        .map((item) => AppointmentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancelAppointment({
    required int appointmentId,
    required CancelAppointmentRequest request,
  }) async {
    await apiClient.put(
      '/Appointments/$appointmentId/cancel',
      body: request.toJson(),
    );
  }
}
