// ignore_for_file: prefer_initializing_formals

import '../models/appointment_revenue_report_model.dart';
import '../models/therapist_performance_report_model.dart';
import '../services/admin_report_api_service.dart';
import '../models/report_therapist_option_model.dart';

class AdminReportRepository {
  final AdminReportApiService _apiService;

  const AdminReportRepository({required AdminReportApiService apiService})
    : _apiService = apiService;

  Future<AppointmentRevenueReportModel> getAppointmentRevenueReport({
    required DateTime fromUtc,
    required DateTime toUtc,
    int? therapistId,
    String? appointmentStatus,
    String? appointmentType,
    String? paymentStatus,
  }) {
    return _apiService.getAppointmentRevenueReport(
      fromUtc: fromUtc,
      toUtc: toUtc,
      therapistId: therapistId,
      appointmentStatus: appointmentStatus,
      appointmentType: appointmentType,
      paymentStatus: paymentStatus,
    );
  }

  Future<TherapistPerformanceReportModel> getTherapistPerformanceReport({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) {
    return _apiService.getTherapistPerformanceReport(
      fromUtc: fromUtc,
      toUtc: toUtc,
    );
  }

  Future<List<ReportTherapistOptionModel>> getTherapists() {
    return _apiService.getTherapists();
  }
}
