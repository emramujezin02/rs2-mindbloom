import '../../../../core/network/api_client.dart';
import '../../../therapist/data/models/therapist_availability_model.dart';
import '../models/appointment_create_request.dart';
import '../models/appointment_model.dart';
import '../models/cancel_appointment_request.dart';
import '../models/occupied_slot_model.dart';
import '../models/therapist_appointment_status.dart';
import '../models/unavailable_date_model.dart';
import '../models/update_appointment_status_request.dart';

class AppointmentApiService {
  final ApiClient apiClient;

  AppointmentApiService({required this.apiClient});

  Future<void> createAppointment(AppointmentCreateRequest request) async {
    await apiClient.post('/Appointments', body: request.toJson());
  }

  Future<List<AppointmentModel>> getMyAppointments() async {
    final response = await apiClient.get('/Appointments/mine');

    return _mapAppointments(response);
  }

  Future<List<AppointmentModel>> getTherapistAppointments() async {
    final response = await apiClient.get('/Appointments/therapist');

    return _mapAppointments(response);
  }

  Future<void> updateTherapistAppointmentStatus({
    required int appointmentId,
    required TherapistAppointmentStatus status,
  }) async {
    final request = UpdateAppointmentStatusRequest(
      appointmentId: appointmentId,
      status: status,
    );

    await apiClient.put('/Appointments/status', body: request.toJson());
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

  List<AppointmentModel> _mapAppointments(dynamic response) {
    if (response == null) {
      return [];
    }

    final dynamic items;

    if (response is Map<String, dynamic>) {
      items = response['items'] ?? response['data'] ?? [];
    } else {
      items = response;
    }

    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map>()
        .map(
          (item) => AppointmentModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<AppointmentModel> getAppointmentDetails(int appointmentId) async {
    final response = await apiClient.get('/Appointments/$appointmentId');

    return AppointmentModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
