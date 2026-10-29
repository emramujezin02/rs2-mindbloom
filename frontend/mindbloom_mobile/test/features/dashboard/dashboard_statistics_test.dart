import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';
import 'package:mindbloom_mobile/features/dashboard/data/models/client_dashboard_model.dart';
import 'package:mindbloom_mobile/features/dashboard/data/services/client_dashboard_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_dashboard_model.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';

void main() {
  test(
    'Client dashboard reads actual amount and currency without recomputing',
    () {
      final dashboard = ClientDashboardModel.fromJson({
        'totalSpent': 425.75,
        'currency': 'USD',
        'completedAppointments': 99,
      });
      expect(dashboard.totalSpent, 425.75);
      expect(
        '${dashboard.totalSpent.toStringAsFixed(2)} ${dashboard.currency}',
        '425.75 USD',
      );
    },
  );

  test('Client without session dates retains null values', () {
    final dashboard = ClientDashboardModel.fromJson({});
    expect(dashboard.lastAppointmentDate, isNull);
    expect(dashboard.nextAppointmentDate, isNull);
    expect(dashboard.totalSpent, 0);
    expect(dashboard.currency, 'USD');
  });

  test('UTC dates on both DST boundaries remain UTC instants', () {
    for (final day in ['2026-03-29', '2026-10-25']) {
      final dashboard = ClientDashboardModel.fromJson({
        'nextAppointmentDate': '${day}T01:00:00Z',
        'lastAppointmentDate': '${day}T00:00:00Z',
      });
      expect(dashboard.nextAppointmentDate!.isUtc, isTrue);
      expect(dashboard.lastAppointmentDate!.isUtc, isTrue);
      expect(
        dashboard.nextAppointmentDate!.difference(
          dashboard.lastAppointmentDate!,
        ),
        const Duration(hours: 1),
      );
    }
  });

  test('Therapist amounts and currency come directly from the API', () {
    final dashboard = TherapistDashboardModel.fromJson({
      'totalEarnings': 175.30,
      'monthlyEarnings': 95.20,
      'weeklyEarnings': 80.10,
      'currency': 'USD',
      'completedAppointments': 20,
    });
    expect(dashboard.totalEarnings, 175.30);
    expect(dashboard.monthlyEarnings, 95.20);
    expect(dashboard.weeklyEarnings, 80.10);
    expect(dashboard.currency, 'USD');
    expect(TherapistDashboardModel.fromJson({}).currency, 'USD');
  });

  test(
    'Client API keeps the existing endpoint and additive response compatibility',
    () async {
      final client = _Client({'totalSpent': 80, 'currency': 'USD'});
      final result = await ClientDashboardApiService(
        apiClient: client,
      ).getDashboard();
      expect(client.endpoint, '/Appointments/client-dashboard');
      expect(result.totalSpent, 80);
      expect(result.currency, 'USD');
    },
  );

  test(
    'Therapist API keeps dashboard route and parses direct receipts',
    () async {
      final client = _Client({'totalEarnings': 175, 'currency': 'USD'});
      final result = await TherapistApiService(
        apiClient: client,
      ).getDashboard();
      expect(client.endpoint, '/Therapists/dashboard');
      expect(result.totalEarnings, 175);
      expect(result.currency, 'USD');
    },
  );
}

class _Client extends ApiClient {
  _Client(this.response) : super(sessionStorage: SessionStorageService());
  final Map<String, dynamic> response;
  String? endpoint;
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    this.endpoint = endpoint;
    return response;
  }
}
