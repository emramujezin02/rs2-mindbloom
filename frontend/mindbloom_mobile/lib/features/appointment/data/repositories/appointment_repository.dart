import '../../../therapist/data/models/therapist_availability_model.dart';
import '../../../../core/models/paged_response.dart';
import '../models/appointment_create_request.dart';
import '../models/appointment_model.dart';
import '../models/cancel_appointment_request.dart';
import '../models/occupied_slot_model.dart';
import '../models/therapist_appointment_status.dart';
import '../models/unavailable_date_model.dart';
import '../services/appointment_api_service.dart';
import 'dart:convert';

import '../../../../core/network/idempotency_key_generator.dart';

class AppointmentRepository {
  final AppointmentApiService apiService;

  final Map<String, String> _appointmentBookingKeys = <String, String>{};

  AppointmentRepository({required this.apiService});

  Future<void> createAppointment(AppointmentCreateRequest request) async {
    final operationKey = jsonEncode(request.toJson());

    final idempotencyKey = _appointmentBookingKeys.putIfAbsent(
      operationKey,
      IdempotencyKeyGenerator.generate,
    );

    try {
      await apiService.createAppointment(
        request,
        idempotencyKey: idempotencyKey,
      );

      _appointmentBookingKeys.remove(operationKey);
    } catch (_) {
      rethrow;
    }
  }

  Future<PagedResponse<AppointmentModel>> getMyAppointments({
    required int pageNumber,
    required int pageSize,
    String? status,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    return apiService.getMyAppointments(
      pageNumber: pageNumber,
      pageSize: pageSize,
      status: status,
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
  }

  Future<PagedResponse<AppointmentModel>> getTherapistAppointments({
    required int pageNumber,
    required int pageSize,
    String? status,
    DateTime? fromUtc,
    DateTime? toUtc,
  }) {
    return apiService.getTherapistAppointments(
      pageNumber: pageNumber,
      pageSize: pageSize,
      status: status,
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
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

  Future<PagedResponse<UnavailableDateModel>> getTherapistUnavailableDates({
    required int therapistId,
    required DateTime fromUtc,
    required DateTime toUtc,
  }) {
    return apiService.getTherapistUnavailableDates(
      therapistId: therapistId,
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
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
