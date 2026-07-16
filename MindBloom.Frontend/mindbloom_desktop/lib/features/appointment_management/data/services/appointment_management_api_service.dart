import '../../../../core/network/api_client.dart';
import '../models/admin_appointment_details_model.dart';
import '../models/admin_appointment_paged_response.dart';

class AppointmentManagementApiService {
  final ApiClient apiClient;

  const AppointmentManagementApiService({required this.apiClient});

  Future<AdminAppointmentPagedResponse> getAppointments({
    required int pageNumber,
    required int pageSize,
    String? search,
    String? status,
    String? type,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool? isPaid,
  }) async {
    final query = <String, String>{
      'PageNumber': pageNumber.toString(),
      'PageSize': pageSize.toString(),
    };

    if (search != null && search.trim().isNotEmpty) {
      query['Search'] = search.trim();
    }

    if (status != null && status.trim().isNotEmpty) {
      query['Status'] = status;
    }

    if (type != null && type.trim().isNotEmpty) {
      query['Type'] = type;
    }

    if (dateFrom != null) {
      query['DateFromUtc'] = dateFrom.toUtc().toIso8601String();
    }

    if (dateTo != null) {
      query['DateToUtc'] = dateTo.toUtc().toIso8601String();
    }

    if (isPaid != null) {
      query['IsPaid'] = isPaid.toString();
    }

    final queryString = Uri(queryParameters: query).query;

    final response = await apiClient.get('/Admin/appointments?$queryString');

    return AdminAppointmentPagedResponse.fromJson(
      response as Map<String, dynamic>,
    );
  }

  Future<AdminAppointmentDetailsModel> getDetails(int appointmentId) async {
    final response = await apiClient.get('/Admin/appointments/$appointmentId');

    return AdminAppointmentDetailsModel.fromJson(
      response as Map<String, dynamic>,
    );
  }

  Future<void> cancelAppointment({
    required int appointmentId,
    required String reason,
  }) async {
    await apiClient.put(
      '/Admin/appointments/$appointmentId/cancel',
      body: {'reason': reason},
    );
  }
}
