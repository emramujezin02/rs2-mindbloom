// ignore_for_file: prefer_initializing_formals

import '../../../../core/network/api_client.dart';
import '../models/appointment_revenue_report_model.dart';
import '../models/report_therapist_option_model.dart';
import '../models/therapist_performance_report_model.dart';

class AdminReportApiService {
  final ApiClient _apiClient;

  const AdminReportApiService({required ApiClient apiClient})
    : _apiClient = apiClient;

  Future<AppointmentRevenueReportModel> getAppointmentRevenueReport({
    required DateTime fromUtc,
    required DateTime toUtc,
    int? therapistId,
    String? appointmentStatus,
    String? appointmentType,
    String? paymentStatus,
  }) async {
    final queryParameters = <String, String>{
      'fromUtc': fromUtc.toUtc().toIso8601String(),
      'toUtc': toUtc.toUtc().toIso8601String(),
    };

    if (therapistId != null) {
      queryParameters['therapistId'] = therapistId.toString();
    }

    if (appointmentStatus != null && appointmentStatus.trim().isNotEmpty) {
      queryParameters['appointmentStatus'] = appointmentStatus.trim();
    }

    if (appointmentType != null && appointmentType.trim().isNotEmpty) {
      queryParameters['appointmentType'] = appointmentType.trim();
    }

    if (paymentStatus != null && paymentStatus.trim().isNotEmpty) {
      queryParameters['paymentStatus'] = paymentStatus.trim();
    }

    final queryString = Uri(queryParameters: queryParameters).query;

    final response = await _apiClient.get(
      '/api/admin/reports/appointments-revenue'
      '?$queryString',
    );

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
    int? therapistId,
    int minimumAppointments = 0,
    String? therapistStatus,
  }) async {
    final queryParameters = <String, String>{
      'fromUtc': fromUtc.toUtc().toIso8601String(),
      'toUtc': toUtc.toUtc().toIso8601String(),
      'minimumAppointments': minimumAppointments.toString(),
    };

    if (therapistId != null) {
      queryParameters['therapistId'] = therapistId.toString();
    }

    if (therapistStatus != null && therapistStatus.trim().isNotEmpty) {
      queryParameters['therapistStatus'] = therapistStatus.trim();
    }

    final queryString = Uri(queryParameters: queryParameters).query;

    final response = await _apiClient.get(
      '/api/admin/reports/therapist-performance'
      '?$queryString',
    );

    if (response is! Map) {
      throw const FormatException(
        'The server returned an invalid therapist performance report response.',
      );
    }

    return TherapistPerformanceReportModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<List<ReportTherapistOptionModel>> getTherapists() async {
    final response = await _apiClient.get('/Therapists');

    if (response is! List) {
      throw const FormatException(
        'The server returned invalid therapist data.',
      );
    }

    final therapists = response
        .whereType<Map>()
        .map(
          (item) => ReportTherapistOptionModel.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where(
          (therapist) =>
              therapist.id > 0 && therapist.fullName.trim().isNotEmpty,
        )
        .toList();

    therapists.sort(
      (first, second) =>
          first.fullName.toLowerCase().compareTo(second.fullName.toLowerCase()),
    );

    return therapists;
  }
}
