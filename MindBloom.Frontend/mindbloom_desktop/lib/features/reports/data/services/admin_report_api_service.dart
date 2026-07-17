// ignore_for_file: prefer_initializing_formals

import '../../../../core/network/api_client.dart';
import '../models/appointment_revenue_report_model.dart';
import '../models/therapist_performance_report_model.dart';

class AdminReportApiService {
  final ApiClient _apiClient;

  const AdminReportApiService({required ApiClient apiClient})
    : _apiClient = apiClient;

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
        'The server returned an invalid appointment revenue report response.',
      );
    }

    return AppointmentRevenueReportModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<TherapistPerformanceReportModel> getTherapistPerformanceReport({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) async {
    final uri = Uri(
      path: '/api/admin/reports/therapist-performance',
      queryParameters: {
        'fromUtc': fromUtc.toUtc().toIso8601String(),
        'toUtc': toUtc.toUtc().toIso8601String(),
      },
    );

    final response = await _apiClient.get(uri.toString());

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid therapist performance report response.',
      );
    }

    return TherapistPerformanceReportModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }
}
