import 'package:mindbloom_desktop/features/payment_management/data/models/admin_payment_details_model.dart';
import 'package:mindbloom_desktop/features/payment_management/data/models/admin_payment_receipt_model.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/core/time/api_utc.dart';
import 'package:mindbloom_desktop/features/appointment_management/data/models/admin_appointment_model.dart';
import 'package:mindbloom_desktop/features/appointment_management/data/models/admin_appointment_details_model.dart';
import 'package:mindbloom_desktop/features/appointment_management/data/repositories/appointment_management_repository.dart';
import 'package:mindbloom_desktop/features/appointment_management/data/services/appointment_management_api_service.dart';
import 'package:mindbloom_desktop/features/appointment_management/presentation/viewmodels/appointment_management_viewmodel.dart';
import 'package:mindbloom_desktop/features/appointment_management/presentation/viewmodels/appointment_management_details_viewmodel.dart';
import 'package:mindbloom_desktop/features/membership_management/data/models/admin_membership_details_model.dart';
import 'package:mindbloom_desktop/features/reports/data/models/appointment_revenue_report_model.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';

void main() {
  for (final value in [
    '2026-11-07T09:00:00Z',
    '2026-11-07T09:00:00',
    '2026-11-07T10:00:00+01:00',
    '2026-11-07T10:00:00+0100',
    '2026-11-07T10:00:00+01',
    '2026-11-07T04:00:00-05:00',
  ]) {
    test('UTC parsing preserves the instant: $value', () {
      final result = ApiUtc.parse(value);
      expect(result.isUtc, isTrue);
      expect(result, DateTime.utc(2026, 11, 7, 9));
      expect(ApiUtc.parse(result.toIso8601String()), result);
      expect(result.toLocal().toUtc(), result);
    });
  }

  test('invalid input retains strict and nullable parsing behavior', () {
    expect(() => ApiUtc.parse('not-a-time'), throwsFormatException);
    expect(ApiUtc.tryParse('not-a-time'), isNull);
    expect(ApiUtc.tryParse(''), isNull);
  });

  for (final suffix in ['', 'Z', '+00:00']) {
    test('list/detail/audit models normalize every UTC field: $suffix', () {
      final json = appointmentJson(suffix);
      final list = AdminAppointmentModel.fromJson(json);
      final details = AdminAppointmentDetailsModel.fromJson(json);
      final expected = DateTime.utc(2026, 11, 7, 9);
      for (final value in [
        list.startUtc,
        list.endUtc,
        list.createdAtUtc,
        details.startUtc,
        details.endUtc,
        details.createdAtUtc,
        details.updatedAtUtc!,
        details.auditHistory.single.changedAtUtc,
      ]) {
        expect(value.isUtc, isTrue);
        expect(value, expected);
      }
      expect(list.id, 1);
      expect(details.clientId, 2);
      expect(details.therapistId, 3);
      expect(list.price, 50.25);
      expect(details.status, 'Pending');
      expect(details.canAdminCancel, isTrue);
      expect(
        DateFormat('dd.MM.yyyy. HH:mm').format(list.startUtc.toLocal()),
        DateFormat('dd.MM.yyyy. HH:mm').format(expected.toLocal()),
      );
    });
  }

  test('nullable updatedAtUtc stays null', () {
    final json = appointmentJson('')..['updatedAtUtc'] = null;
    expect(AdminAppointmentDetailsModel.fromJson(json).updatedAtUtc, isNull);
  });

  test('appointment revenue period and rows use the same UTC parser', () {
    final report = AppointmentRevenueReportModel.fromJson({
      'fromUtc': '2026-11-07T09:00:00',
      'toUtc': '2026-11-07T11:00:00+01:00',
      'generatedAtUtc': '2026-11-07T11:00:00Z',
      'appointments': [
        {
          'appointmentId': 1,
          'startUtc': '2026-11-07T09:00:00',
          'endUtc': '2026-11-07T11:00:00+01:00',
          'price': 50.25,
        },
      ],
    });
    expect(report.fromUtc, DateTime.utc(2026, 11, 7, 9));
    expect(report.toUtc, DateTime.utc(2026, 11, 7, 10));
    expect(report.generatedAtUtc, DateTime.utc(2026, 11, 7, 11));
    expect(report.appointments.single.startUtc.isUtc, isTrue);
    expect(report.appointments.single.endUtc, report.toUtc);
    expect(report.appointments.single.price, 50.25);
  });

  test(
    'membership appointment timestamps normalize without changing unrelated dates',
    () {
      final usage = AdminMembershipUsageModel.fromJson({
        'appointmentStartUtc': '2026-11-07T09:00:00',
        'appointmentEndUtc': '2026-11-07T11:00:00+01:00',
      });
      expect(usage.appointmentStartUtc.isUtc, isTrue);
      expect(usage.appointmentStartUtc, DateTime.utc(2026, 11, 7, 9));
      expect(usage.appointmentEndUtc, DateTime.utc(2026, 11, 7, 10));
      final missing = AdminMembershipUsageModel.fromJson({});
      expect(
        missing.appointmentStartUtc,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    },
  );

  test(
    'list and details viewmodels preserve loaded UTC data and local date filters',
    () async {
      final api = _SyntheticApi();
      final repository = AppointmentManagementRepository(
        apiService: AppointmentManagementApiService(apiClient: api),
      );
      final list = AppointmentManagementViewModel(repository: repository);
      final details = AppointmentManagementDetailsViewModel(
        repository: repository,
      );
      addTearDown(list.dispose);
      addTearDown(details.dispose);
      final localDate = DateTime(2026, 11, 7);
      await list.load(dateFrom: localDate, updateFilters: true);
      await details.load(1);
      expect(list.error, isNull);
      expect(details.error, isNull);
      expect(list.appointments.single.startUtc.isUtc, isTrue);
      expect(details.appointment!.startUtc, list.appointments.single.startUtc);
      expect(list.totalCount, 1);
      expect(list.currentDateFrom, same(localDate));
      expect(
        api.requests.first.queryParameters['DateFromUtc'],
        localDate.toUtc().toIso8601String(),
      );
      expect(api.requests.map((uri) => uri.path), [
        '/Admin/appointments',
        '/Admin/appointments/1',
      ]);
    },
  );

  for (final suffix in ['', 'Z', '+00:00']) {
    test('payment detail/receipt retain embedded appointment UTC: $suffix', () {
      final json = <String, dynamic>{
        'appointmentStartUtc': '2026-11-07T09:00:00$suffix',
        'appointmentEndUtc': '2026-11-07T10:00:00$suffix',
        'amount': 50.25,
        'currency': 'usd',
      };
      final details = AdminPaymentDetailsModel.fromJson(json);
      final receipt = AdminPaymentReceiptModel.fromJson(json);
      for (final value in [
        details.appointmentStartUtc!,
        receipt.appointmentStartUtc!,
      ]) {
        expect(value.isUtc, isTrue);
        expect(value, DateTime.utc(2026, 11, 7, 9));
      }
      expect(details.appointmentEndUtc, DateTime.utc(2026, 11, 7, 10));
      expect(receipt.appointmentEndUtc, details.appointmentEndUtc);
      expect(details.amount, 50.25);
      expect(details.currency, 'usd');
    });
  }

  test(
    'missing or invalid embedded payment appointment dates stay nullable',
    () {
      final json = <String, dynamic>{
        'appointmentStartUtc': null,
        'appointmentEndUtc': 'invalid',
      };
      final details = AdminPaymentDetailsModel.fromJson(json);
      final receipt = AdminPaymentReceiptModel.fromJson(json);
      expect(details.appointmentStartUtc, isNull);
      expect(details.appointmentEndUtc, isNull);
      expect(receipt.appointmentStartUtc, isNull);
      expect(receipt.appointmentEndUtc, isNull);
    },
  );

  // Windows' explicit Sarajevo zone rules provide a deterministic presentation
  // oracle without changing the machine timezone or adding a runtime dependency.
  for (final sample in [
    ('2026-11-07T09:00:00', '2026-11-07T10:00:00+01:00'),
    ('2026-11-07T10:00:00+01:00', '2026-11-07T10:00:00+01:00'),
    ('2026-07-07T09:00:00', '2026-07-07T11:00:00+02:00'),
    ('2026-07-07T11:00:00+02:00', '2026-07-07T11:00:00+02:00'),
  ]) {
    test(
      'Europe/Sarajevo deterministic presentation: ${sample.$1}',
      () async {
        final instant = ApiUtc.parse(sample.$1);
        final script =
            '''
\$ErrorActionPreference='Stop'
\$zone=[TimeZoneInfo]::FindSystemTimeZoneById('Central European Standard Time')
\$instant=[DateTimeOffset]::Parse('${instant.toIso8601String()}',[Globalization.CultureInfo]::InvariantCulture)
[TimeZoneInfo]::ConvertTime(\$instant,\$zone).ToString('yyyy-MM-ddTHH:mm:sszzz')
''';
        final result = await Process.run('powershell.exe', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          script,
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout.toString().trim(), sample.$2);
      },
      skip: !Platform.isWindows,
    );
  }
}

Map<String, dynamic> appointmentJson(String suffix) => {
  'id': 1,
  'clientId': 2,
  'therapistId': 3,
  'clientName': 'Synthetic client',
  'therapistName': 'Synthetic therapist',
  'startUtc': '2026-11-07T09:00:00$suffix',
  'endUtc': '2026-11-07T09:00:00$suffix',
  'createdAtUtc': '2026-11-07T09:00:00$suffix',
  'updatedAtUtc': '2026-11-07T09:00:00$suffix',
  'status': 'Pending',
  'type': 'Online',
  'price': 50.25,
  'canAdminCancel': true,
  'auditHistory': [
    {'newStatus': 'Pending', 'changedAtUtc': '2026-11-07T09:00:00$suffix'},
  ],
};

class _SyntheticApi extends ApiClient {
  final requests = <Uri>[];
  _SyntheticApi() : super(sessionStorage: SessionStorageService());

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final uri = Uri.parse(endpoint);
    requests.add(uri);
    if (uri.path == '/Admin/appointments/1') return appointmentJson('');
    if (uri.path == '/Admin/appointments') {
      return {
        'items': [appointmentJson('')],
        'pageNumber': 1,
        'pageSize': 10,
        'totalCount': 1,
        'totalPages': 1,
      };
    }
    throw StateError('Unexpected synthetic API path');
  }
}
