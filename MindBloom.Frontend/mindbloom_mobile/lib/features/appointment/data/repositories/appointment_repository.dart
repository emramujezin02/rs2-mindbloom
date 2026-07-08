import '../models/appointment_create_request.dart';
import '../services/appointment_api_service.dart';

class AppointmentRepository {
  final AppointmentApiService apiService;

  AppointmentRepository({required this.apiService});

  Future<void> createAppointment(AppointmentCreateRequest request) {
    return apiService.createAppointment(request);
  }
}
