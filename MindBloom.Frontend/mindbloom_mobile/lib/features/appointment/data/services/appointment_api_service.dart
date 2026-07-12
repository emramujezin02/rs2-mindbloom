import '../../../../core/network/api_client.dart';
import '../../../therapist/data/models/therapist_availability_model.dart';
import '../models/appointment_create_request.dart';
import '../models/appointment_model.dart';
import '../models/cancel_appointment_request.dart';
import '../models/occupied_slot_model.dart';
import '../models/unavailable_date_model.dart';

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

  Future<List<TherapistAvailabilityModel>> getTherapistAvailabilities(
    int therapistId,
  ) async {
    final response = await apiClient.get(
      '/Therapists/$therapistId/availability',
    );

    return (response as List)
        .map(
          (item) =>
              TherapistAvailabilityModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<UnavailableDateModel>> getTherapistUnavailableDates(
    int therapistId,
  ) async {
    final response = await apiClient.get(
      '/Therapists/$therapistId/unavailable-dates',
    );

    return (response as List)
        .map(
          (item) => UnavailableDateModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<OccupiedSlotModel>> getOccupiedSlots({
    required int therapistId,
    required DateTime date,
  }) async {
    final dateValue =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final response = await apiClient.get(
      '/Appointments/therapist/'
      '$therapistId/occupied-slots'
      '?date=$dateValue',
    );

    return (response as List)
        .map((item) => OccupiedSlotModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
