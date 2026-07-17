import '../../../../core/network/api_client.dart';
import '../models/appointment_revenue_report_model.dart';

class AdminReportApiService {
  final ApiClient _apiClient;

  const AdminReportApiService({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  Future<AppointmentRevenueReportModel> getAppointmentRevenueReport({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) async {
    final uri = Uri(
      path: '/api/admin/reports/appointments-revenue',
      queryParameters: {
        'fromUtc': fromUtc.toUtc().toIso8601String(),
        'toUtc': toUtc.toUtc().toIso8601String(),
      },
    );

    final response = await _apiClient.get(uri.toString());

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid report response.',
      );
    }

    return AppointmentRevenueReportModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
