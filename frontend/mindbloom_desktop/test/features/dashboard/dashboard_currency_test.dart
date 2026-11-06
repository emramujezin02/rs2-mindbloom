import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';
import 'package:mindbloom_desktop/features/dashboard/data/repositories/admin_dashboard_repository.dart';
import 'package:mindbloom_desktop/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:mindbloom_desktop/features/dashboard/presentation/viewmodels/admin_dashboard_viewmodel.dart';

Map<String, dynamic> series(String? currency, double amount, {String? label}) => {
  'currencyKey': currency ?? 'invalid:', 'currency': currency,
  'currencyLabel': label ?? currency ?? 'Unknown currency (missing)',
  'totalRevenue': amount, 'currentMonthRevenue': amount, 'periodRevenue': amount,
  'revenueByMonth': [
    {'year': 2026, 'month': 1, 'label': '2026-01', 'revenue': amount},
  ],
};

Map<String, dynamic> payload(List<Map<String, dynamic>> currencies) => {
  'fromUtc': '2026-01-01T00:00:00Z', 'toUtc': '2026-12-31T00:00:00Z',
  'generatedAtUtc': '2026-11-01T12:00:00Z',
  'totalUsers': 5, 'totalAppointments': 6, 'activeMemberships': 1,
  'totalRevenue': 50, 'currentMonthRevenue': 50, 'periodRevenue': 50,
  'revenueByCurrency': currencies,
};

Future<void> pumpFinance(WidgetTester tester, AdminDashboardModel model,
    {double width = 1024, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
    data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(scale)),
    child: SingleChildScrollView(child: Column(children: [
      DashboardFinancialSummary(dashboard: model),
      DashboardRevenueByMonthChart(dashboard: model),
    ])),
  ))));
  await tester.pumpAndSettle();
}

void main() {
  test('JSON retains all currency series and nonfinancial metrics', () {
    final model = AdminDashboardModel.fromJson(payload([
      series('USD', 50), series('BAM', 20), series('XYZ', 30),
    ]));
    expect(model.revenueByCurrency.map((x) => x.currency), ['USD', 'BAM', 'XYZ']);
    expect(model.revenueByCurrency.map((x) => x.totalRevenue), [50, 20, 30]);
    expect(model.totalUsers, 5);
    expect(model.totalAppointments, 6);
    expect(model.activeMemberships, 1);
  });

  test('foreign currency alone still counts as dashboard activity', () {
    final model = AdminDashboardModel.fromJson({
      'revenueByCurrency': [series('BAM', 20)],
    });
    expect(model.hasAnyData, isTrue);
    expect(model.totalRevenue, 0);
  });

  for (final code in ['USD', 'BAM', 'XYZ']) {
    testWidgets('single $code uses actual code in all cards and tooltip', (tester) async {
      await pumpFinance(tester, AdminDashboardModel.fromJson(payload([series(code, 50)])));
      expect(find.text('50,00 $code'), findsNWidgets(3));
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final group = chart.data.barGroups.single;
      final tooltip = chart.data.barTouchData.touchTooltipData.getTooltipItem(
        group, 0, group.barRods.single, 0,
      );
      expect(tooltip!.text, '50,00 $code');
      expect(group.barRods.single.toY, 50);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('USD and BAM remain separate in cards and monthly plots', (tester) async {
    await pumpFinance(tester, AdminDashboardModel.fromJson(payload([
      series('USD', 50), series('BAM', 20),
    ])));
    expect(find.text('50,00 USD'), findsNWidgets(3));
    expect(find.text('20,00 BAM'), findsNWidgets(3));
    expect(find.text('70,00 USD'), findsNothing);
    expect(find.byType(BarChart), findsNWidgets(2));
    for (final chart in tester.widgetList<BarChart>(find.byType(BarChart))) {
      final code = (chart.key! as ValueKey<String>).value.split('-').last;
      final group = chart.data.barGroups.single;
      final tooltip = chart.data.barTouchData.touchTooltipData.getTooltipItem(
        group, 0, group.barRods.single, 0,
      );
      expect(tooltip!.text, endsWith(code));
    }
  });

  testWidgets('missing currency remains explicitly unknown', (tester) async {
    await pumpFinance(tester, AdminDashboardModel.fromJson(payload([series(null, 20)])));
    expect(find.text('20,00 Unknown currency (missing)'), findsNWidgets(3));
    expect(find.textContaining(' USD'), findsNothing);
    expect(find.textContaining(' BAM'), findsNothing);
  });

  testWidgets('empty collection has empty state without fabricated USD transactions', (tester) async {
    await pumpFinance(tester, AdminDashboardModel.fromJson(payload([])));
    expect(find.text('No payments with Paid status.'), findsOneWidget);
    expect(find.text('No paid payments for this period.'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });

  testWidgets('old API numeric totals are never guessed to be USD', (tester) async {
    final json = payload([])..remove('revenueByCurrency');
    await pumpFinance(tester, AdminDashboardModel.fromJson(json));
    expect(find.textContaining('Currency breakdown unavailable'), findsNWidgets(2));
    expect(find.text('50,00 USD'), findsNothing);
    expect(find.byType(BarChart), findsNothing);
  });

  for (final width in [320.0, 390.0, 600.0, 1024.0]) {
    testWidgets('currency cards and charts fit $width with enlarged text', (tester) async {
      await pumpFinance(tester, AdminDashboardModel.fromJson(payload([
        series('USD', 50), series('BAM', 20),
        series(null, 30, label: 'Unknown currency (invalid: TOOLONG)'),
      ])), width: width, scale: 1.5);
      expect(tester.takeException(), isNull);
      expect(find.byType(BarChart), findsNWidgets(3));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('fake repository loading, failure, retry and UTC period behavior remain intact', () async {
    final repository = FakeCurrencyDashboardRepository();
    final vm = AdminDashboardViewModel(repository: repository);
    addTearDown(vm.dispose);
    final pending = vm.loadDashboard();
    expect(vm.isLoading, isTrue);
    repository.next.completeError(Exception('Synthetic API error'));
    await pending;
    expect(vm.isLoading, isFalse);
    expect(vm.errorMessage, contains('Synthetic API error'));
    repository.next = Completer<AdminDashboardModel>();
    vm.setCustomFromDate(DateTime(2026, 1, 10));
    vm.setCustomToDate(DateTime(2026, 1, 20));
    final retry = vm.refreshDashboard();
    repository.next.complete(AdminDashboardModel.fromJson(payload([
      series('USD', 50), series('BAM', 20),
    ])));
    await retry;
    expect(vm.errorMessage, isNull);
    expect(vm.selectedPeriod, AdminDashboardPeriod.custom);
    expect(repository.from, DateTime.utc(2026, 1, 10));
    expect(repository.to, DateTime.utc(2026, 1, 20, 23, 59, 59, 999));
    expect(vm.dashboard!.totalUsers, 5);
    expect(vm.dashboard!.revenueByCurrency.length, 2);
  });
}

class FakeCurrencyDashboardRepository implements AdminDashboardRepository {
  Completer<AdminDashboardModel> next = Completer<AdminDashboardModel>();
  DateTime? from;
  DateTime? to;
  @override
  Future<AdminDashboardModel> getDashboard({required DateTime fromUtc, required DateTime toUtc}) {
    from = fromUtc;
    to = toUtc;
    return next.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
