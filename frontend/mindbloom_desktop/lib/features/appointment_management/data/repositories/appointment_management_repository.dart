import '../models/admin_appointment_details_model.dart';
import '../models/admin_appointment_paged_response.dart';
import '../services/appointment_management_api_service.dart';

class AppointmentManagementRepository {
  final AppointmentManagementApiService apiService;

  const AppointmentManagementRepository({required this.apiService});

  Future<AdminAppointmentPagedResponse> getAppointments({
    required int pageNumber,
    required int pageSize,
    String? search,
    String? status,
    String? type,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? isPaid,
  }) {
    return apiService.getAppointments(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      status: status,
      type: type,
      dateFrom: dateFrom,
      dateTo: dateTo,
      isPaid: isPaid,
    );
  }

  Future<AdminAppointmentDetailsModel> getDetails(int appointmentId) {
    return apiService.getDetails(appointmentId);
  }

  Future<void> cancelAppointment({
    required int appointmentId,
    required String reason,
  }) {
    return apiService.cancelAppointment(
      appointmentId: appointmentId,
      reason: reason,
    );
  }
}
