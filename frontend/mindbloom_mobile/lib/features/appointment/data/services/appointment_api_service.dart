import '../../../../core/network/api_client.dart';
import '../../../../core/models/paged_response.dart';
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

  Future<void> createAppointment(
    AppointmentCreateRequest request, {
    String? idempotencyKey,
  }) async {
    await apiClient.post(
      '/Appointments',
      body: request.toJson(),
      idempotencyKey: idempotencyKey,
    );
  }

  Future<PagedResponse<AppointmentModel>> getMyAppointments({
    required int pageNumber,
    required int pageSize,
    String? status,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final query = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (fromUtc != null) 'fromUtc': fromUtc.toUtc().toIso8601String(),
      if (toUtc != null) 'toUtc': toUtc.toUtc().toIso8601String(),
    };

    final response = await apiClient.get(
      Uri(path: '/Appointments/mine', queryParameters: query).toString(),
    );

    return PagedResponse.fromJson(
      response as Map<String, dynamic>,
      AppointmentModel.fromJson,
    );
  }

  Future<PagedResponse<AppointmentModel>> getTherapistAppointments({
    required int pageNumber,
    required int pageSize,
    String? status,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) async {
    final query = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (fromUtc != null) 'fromUtc': fromUtc.toUtc().toIso8601String(),
      if (toUtc != null) 'toUtc': toUtc.toUtc().toIso8601String(),
    };

    final response = await apiClient.get(
      Uri(path: '/Appointments/therapist', queryParameters: query).toString(),
    );

    return PagedResponse.fromJson(
      response as Map<String, dynamic>,
      AppointmentModel.fromJson,
    );
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

  Future<PagedResponse<UnavailableDateModel>> getTherapistUnavailableDates({
    required int therapistId,
    required DateTime fromUtc,
    required DateTime toUtc,
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final response = await apiClient.get(
      Uri(
        path: '/Therapists/$therapistId/unavailable-dates',
        queryParameters: {
          'pageNumber': pageNumber.toString(),
          'pageSize': pageSize.toString(),
          'fromUtc': fromUtc.toUtc().toIso8601String(),
          'toUtc': toUtc.toUtc().toIso8601String(),
        },
      ).toString(),
    );

    return PagedResponse.fromJson(
      response as Map<String, dynamic>,
      UnavailableDateModel.fromJson,
    );
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

  Future<AppointmentModel> getAppointmentDetails(int appointmentId) async {
    final response = await apiClient.get('/Appointments/$appointmentId');

    return AppointmentModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
