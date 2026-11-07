import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/features/reports/data/services/admin_report_api_service.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';

class _SyntheticSession extends SessionStorageService {
  @override
  Future<String?> getAccessToken() async => 'synthetic-test-token';
}

void main() {
  final from = DateTime.utc(2026, 11, 6);
  final to = DateTime.utc(2026, 11, 7, 23, 59, 59);
  Map<String, dynamic> emptyReport() => {
    'fromUtc': from.toIso8601String(),
    'toUtc': to.toIso8601String(),
    'generatedAtUtc': DateTime.utc(2026, 11, 7).toIso8601String(),
    'generatedByAdmin': 'Synthetic Administrator',
    'appointments': <dynamic>[],
    'therapists': <dynamic>[],
  };
  AdminReportApiService service() => AdminReportApiService(
    apiClient: ApiClient(sessionStorage: _SyntheticSession()),
  );

  test('revenue uses one api prefix and preserves every filter with empty data', () async {
    var calls = 0;
    await http.runWithClient(() async {
      final report = await service().getAppointmentRevenueReport(
        fromUtc: from, toUtc: to, therapistId: 7,
        appointmentStatus: 'Pending', appointmentType: 'Online', paymentStatus: 'Paid',
      );
      expect(report.appointments, isEmpty);
      expect(report.totalAppointments, 0);
    }, () => MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.url, Uri.parse('http://localhost:8080/api/admin/reports/appointments-revenue').replace(queryParameters: {
        'fromUtc': from.toIso8601String(), 'toUtc': to.toIso8601String(),
        'therapistId': '7', 'appointmentStatus': 'Pending',
        'appointmentType': 'Online', 'paymentStatus': 'Paid',
      }));
      expect(request.headers['Authorization'], 'Bearer synthetic-test-token');
      return http.Response(jsonEncode(emptyReport()), 200, headers: {'content-type': 'application/json'});
    }));
    expect(calls, 1);
  });

  test('performance uses one api prefix and preserves optional query filters', () async {
    var calls = 0;
    await http.runWithClient(() async {
      final report = await service().getTherapistPerformanceReport(
        fromUtc: from, toUtc: to, minimumAppointments: 1, therapistStatus: 'Approved',
      );
      expect(report.therapists, isEmpty);
    }, () => MockClient((request) async {
      calls++;
      expect(request.url, Uri.parse('http://localhost:8080/api/admin/reports/therapist-performance').replace(queryParameters: {
        'fromUtc': from.toIso8601String(), 'toUtc': to.toIso8601String(),
        'minimumAppointments': '1', 'therapistStatus': 'Approved',
      }));
      expect(request.url.queryParameters.containsKey('therapistId'), isFalse);
      return http.Response(jsonEncode(emptyReport()), 200, headers: {'content-type': 'application/json'});
    }));
    expect(calls, 1);
  });

  test('therapist filter lookup retains its existing endpoint', () async {
    await http.runWithClient(() async {
      expect(await service().getTherapists(), isEmpty);
    }, () => MockClient((request) async {
      expect(request.url, Uri.parse('http://localhost:8080/api/Therapists?Page=1&PageSize=50'));
      return http.Response(jsonEncode({'items': <dynamic>[], 'hasNextPage': false}), 200);
    }));
  });
}