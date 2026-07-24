import '../../../therapist/data/models/therapist_availability_model.dart';
import '../models/appointment_create_request.dart';
import '../models/appointment_model.dart';
import '../models/cancel_appointment_request.dart';
import '../models/occupied_slot_model.dart';
import '../models/therapist_appointment_status.dart';
import '../models/unavailable_date_model.dart';
import '../services/appointment_api_service.dart';

class AppointmentRepository {
  final AppointmentApiService apiService;

  AppointmentRepository({required this.apiService});

  Future<void> createAppointment(AppointmentCreateRequest request) {
    return apiService.createAppointment(request);
  }

  Future<List<AppointmentModel>> getMyAppointments() {
    return apiService.getMyAppointments();
  }

  Future<List<AppointmentModel>> getTherapistAppointments() {
    return apiService.getTherapistAppointments();
  }

  Future<void> updateTherapistAppointmentStatus({
    required int appointmentId,
    required TherapistAppointmentStatus status,
  }) {
    return apiService.updateTherapistAppointmentStatus(
      appointmentId: appointmentId,
      status: status,
    );
  }

  Future<void> cancelAppointment({
    required int appointmentId,
    required String reason,
  }) {
    return apiService.cancelAppointment(
      appointmentId: appointmentId,
      request: CancelAppointmentRequest(reason: reason),
    );
  }

  Future<List<TherapistAvailabilityModel>> getTherapistAvailabilities(
    int therapistId,
  ) {
    return apiService.getTherapistAvailabilities(therapistId);
  }

  Future<List<UnavailableDateModel>> getTherapistUnavailableDates(
    int therapistId,
  ) {
    return apiService.getTherapistUnavailableDates(therapistId);
  }

  Future<List<OccupiedSlotModel>> getOccupiedSlots({
    required int therapistId,
    required DateTime date,
  }) {
    return apiService.getOccupiedSlots(therapistId: therapistId, date: date);
  }

  Future<AppointmentModel> getAppointmentDetails(int appointmentId) {
    return apiService.getAppointmentDetails(appointmentId);
  }
}
