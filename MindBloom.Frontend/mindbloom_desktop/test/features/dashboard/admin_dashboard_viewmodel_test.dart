import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';
import 'package:mindbloom_desktop/features/dashboard/data/repositories/admin_dashboard_repository.dart';
import 'package:mindbloom_desktop/features/dashboard/presentation/viewmodels/admin_dashboard_viewmodel.dart';

class FakeAdminDashboardRepository implements AdminDashboardRepository {
  AdminDashboardModel? response;

  Object? error;

  int callCount = 0;

  DateTime? receivedFromUtc;
  DateTime? receivedToUtc;

  @override
  Future<AdminDashboardModel> getDashboard({
    required DateTime fromUtc,
    required DateTime toUtc,
  }) async {
    callCount++;

    receivedFromUtc = fromUtc;

    receivedToUtc = toUtc;

    if (error != null) {
      throw error!;
    }

    return response!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

AdminDashboardModel createDashboard({
  int totalUsers = 100,
  int totalAppointments = 50,
  double totalRevenue = 2500,
}) {
  return AdminDashboardModel(
    fromUtc: DateTime.utc(2026, 1, 1),
    toUtc: DateTime.utc(2026, 8, 22),
    generatedAtUtc: DateTime.utc(2026, 8, 22, 12),
    totalUsers: totalUsers,
    activeClients: 60,
    totalTherapists: 20,
    verifiedTherapists: 15,
    pendingTherapists: 3,
    totalAppointments: totalAppointments,
    todayAppointments: 4,
    completedAppointments: 30,
    cancelledAppointments: 5,
    totalRevenue: totalRevenue,
    currentMonthRevenue: 500,
    periodRevenue: 1800,
    activeMemberships: 10,
    pendingReviews: 2,
    publishedArticles: 8,
    activeWorkshops: 3,
    appointmentsByStatus: const [
      AdminDashboardCountItemModel(label: 'Completed', count: 30),
      AdminDashboardCountItemModel(label: 'Cancelled', count: 5),
    ],
    revenueByMonth: const [
      AdminDashboardMonthlyRevenueItemModel(
        year: 2026,
        month: 8,
        label: 'Aug 2026',
        revenue: 500,
      ),
    ],
    newUsersByMonth: const [
      AdminDashboardMonthlyCountItemModel(
        year: 2026,
        month: 8,
        label: 'Aug 2026',
        count: 10,
      ),
    ],
    appointmentsByTherapyApproach: const [
      AdminDashboardCountItemModel(label: 'CBT', count: 15),
    ],
    verifiedTherapistsByMonth: const [
      AdminDashboardMonthlyCountItemModel(
        year: 2026,
        month: 8,
        label: 'Aug 2026',
        count: 3,
      ),
    ],
  );
}

void main() {
  group('AdminDashboardViewModel', () {
    test('default period is last six months', () {
      final repository = FakeAdminDashboardRepository();

      final viewModel = AdminDashboardViewModel(repository: repository);

      expect(viewModel.selectedPeriod, AdminDashboardPeriod.last6Months);

      expect(viewModel.fromDate.isAfter(viewModel.toDate), isFalse);
    });

    test('loadDashboard loads dashboard data', () async {
      final repository = FakeAdminDashboardRepository();

      repository.response = createDashboard();

      final viewModel = AdminDashboardViewModel(repository: repository);

      await viewModel.loadDashboard();

      expect(repository.callCount, 1);

      expect(viewModel.dashboard, isNotNull);

      expect(viewModel.dashboard!.totalUsers, 100);

      expect(viewModel.dashboard!.totalAppointments, 50);

      expect(viewModel.isLoading, isFalse);

      expect(viewModel.errorMessage, isNull);
    });

    test('loadDashboard sends full UTC day range', () async {
      final repository = FakeAdminDashboardRepository();

      repository.response = createDashboard();

      final viewModel = AdminDashboardViewModel(repository: repository);

      viewModel.setCustomFromDate(DateTime(2026, 5, 10));

      viewModel.setCustomToDate(DateTime(2026, 5, 20));

      await viewModel.loadDashboard();

      expect(repository.receivedFromUtc, DateTime.utc(2026, 5, 10));

      expect(
        repository.receivedToUtc,
        DateTime.utc(2026, 5, 20, 23, 59, 59, 999),
      );
    });

    test('invalid custom period does not call repository', () async {
      final repository = FakeAdminDashboardRepository();

      repository.response = createDashboard();

      final viewModel = AdminDashboardViewModel(repository: repository);

      viewModel.setCustomFromDate(DateTime(2026, 8, 20));

      viewModel.setCustomToDate(DateTime(2026, 8, 10));

      await viewModel.loadDashboard();

      expect(repository.callCount, 0);

      expect(
        viewModel.errorMessage,
        'The start date cannot be later than the end date.',
      );
    });

    test('repository failure sets dashboard error state', () async {
      final repository = FakeAdminDashboardRepository();

      repository.error = Exception('Dashboard unavailable.');

      final viewModel = AdminDashboardViewModel(repository: repository);

      await viewModel.loadDashboard();

      expect(viewModel.errorMessage, 'Dashboard unavailable.');

      expect(viewModel.isLoading, isFalse);
    });

    test('setPeriod changes period and reloads dashboard', () async {
      final repository = FakeAdminDashboardRepository();

      repository.response = createDashboard();

      final viewModel = AdminDashboardViewModel(repository: repository);

      await viewModel.setPeriod(AdminDashboardPeriod.last30Days);

      expect(viewModel.selectedPeriod, AdminDashboardPeriod.last30Days);

      expect(repository.callCount, 1);

      final difference = viewModel.toDate.difference(viewModel.fromDate).inDays;

      expect(difference, 29);
    });

    test('custom period does not automatically call repository', () async {
      final repository = FakeAdminDashboardRepository();

      repository.response = createDashboard();

      final viewModel = AdminDashboardViewModel(repository: repository);

      await viewModel.setPeriod(AdminDashboardPeriod.custom);

      expect(viewModel.selectedPeriod, AdminDashboardPeriod.custom);

      expect(repository.callCount, 0);
    });

    test('dashboard model reports whether data exists', () {
      final dashboard = createDashboard();

      expect(dashboard.hasAnyData, isTrue);

      expect(dashboard.otherAppointments, 15);

      expect(dashboard.rejectedTherapists, 2);
    });
  });
}
