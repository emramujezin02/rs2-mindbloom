import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/features/dashboard/data/models/admin_dahsboard_model.dart';

import '../../../../app/di/injection.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../viewmodels/admin_dashboard_viewmodel.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AdminDashboardViewModel _viewModel =
      AppInjection.createAdminDashboardViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadDashboard();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() {
    return _viewModel.refreshDashboard();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel.isLoading && _viewModel.dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.dashboard == null) {
      return _DashboardErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _refresh,
      );
    }

    final dashboard = _viewModel.dashboard;

    if (dashboard == null) {
      return _DashboardErrorState(
        message: 'Dashboard data could not be loaded.',
        onRetry: _refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        key: const PageStorageKey<String>('admin-dashboard'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHeader(
              isRefreshing: _viewModel.isLoading,
              onRefresh: _refresh,
            ),

            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              _InlineErrorMessage(message: _viewModel.errorMessage!),
            ],

            const SizedBox(height: 28),

            _SummaryCards(dashboard: dashboard),

            const SizedBox(height: 28),

            _ChartsSection(dashboard: dashboard),

            const SizedBox(height: 28),

            _AdditionalStatistics(dashboard: dashboard),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool isRefreshing;

  final Future<void> Function() onRefresh;

  const _DashboardHeader({required this.isRefreshing, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    final currentUser = session.currentUser;

    final username = currentUser?.username.trim() ?? '';

    final email = currentUser?.email.trim() ?? '';

    final displayName = username.isNotEmpty ? username : 'Administrator';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;

        final introduction = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $displayName',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              email.isEmpty
                  ? 'MindBloom administration overview'
                  : 'Signed in as $email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        );

        final refreshButton = OutlinedButton.icon(
          onPressed: isRefreshing
              ? null
              : () {
                  onRefresh();
                },
          icon: isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(isRefreshing ? 'Refreshing...' : 'Refresh'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [introduction, const SizedBox(height: 16), refreshButton],
          );
        }

        return Row(
          children: [
            Expanded(child: introduction),
            const SizedBox(width: 20),
            refreshButton,
          ],
        );
      },
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _SummaryCards({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'bs_BA',
      symbol: 'KM',
      decimalDigits: 2,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 1250
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;

        const spacing = 16.0;

        final itemWidth =
            (constraints.maxWidth - ((columnCount - 1) * spacing)) /
            columnCount;

        final cards = [
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.people,
            title: 'Users',
            value: dashboard.totalUsers.toString(),
            description: '${dashboard.totalClients} clients',
          ),
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.psychology,
            title: 'Therapists',
            value: dashboard.totalTherapists.toString(),
            description: '${dashboard.pendingTherapists} pending verification',
            isWarning: dashboard.pendingTherapists > 0,
          ),
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.calendar_month,
            title: 'Appointments',
            value: dashboard.totalAppointments.toString(),
            description: '${dashboard.completedAppointments} completed',
          ),
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.payments,
            title: 'Revenue',
            value: currencyFormatter.format(dashboard.totalRevenue),
            description: '${dashboard.totalPayments} payments',
          ),
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.reviews,
            title: 'Reviews',
            value: dashboard.totalReviews.toString(),
            description: 'Submitted reviews',
          ),
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.pending_actions,
            title: 'Pending appointments',
            value: dashboard.pendingAppointments.toString(),
            description: 'Waiting for therapist action',
            isWarning: dashboard.pendingAppointments > 0,
          ),
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.check_circle,
            title: 'Approved therapists',
            value: dashboard.approvedTherapists.toString(),
            description: 'Visible to clients',
          ),
          _DashboardSummaryCard(
            width: itemWidth,
            icon: Icons.cancel,
            title: 'Cancelled appointments',
            value: dashboard.cancelledAppointments.toString(),
            description: 'Cancelled sessions',
          ),
        ];

        return Wrap(spacing: spacing, runSpacing: spacing, children: cards);
      },
    );
  }
}

class _DashboardSummaryCard extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String value;
  final String description;
  final bool isWarning;

  const _DashboardSummaryCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = isWarning ? colorScheme.error : colorScheme.primary;

    final backgroundColor = isWarning
        ? colorScheme.errorContainer
        : colorScheme.primaryContainer;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartsSection extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _ChartsSection({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final displaySideBySide = constraints.maxWidth >= 1050;

        final therapistChart = _TherapistVerificationChart(
          dashboard: dashboard,
        );

        final appointmentChart = _AppointmentStatusChart(dashboard: dashboard);

        if (!displaySideBySide) {
          return Column(
            children: [
              therapistChart,
              const SizedBox(height: 18),
              appointmentChart,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: therapistChart),
            const SizedBox(width: 18),
            Expanded(child: appointmentChart),
          ],
        );
      },
    );
  }
}

class _TherapistVerificationChart extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _TherapistVerificationChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final total =
        dashboard.approvedTherapists +
        dashboard.pendingTherapists +
        dashboard.rejectedTherapists;

    return _DashboardChartCard(
      title: 'Therapist verification',
      subtitle: 'Distribution by verification status',
      child: total == 0
          ? const _EmptyChart(message: 'No therapist verification data.')
          : Column(
              children: [
                SizedBox(
                  height: 260,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 55,
                      sectionsSpace: 3,
                      sections: [
                        PieChartSectionData(
                          value: dashboard.approvedTherapists.toDouble(),
                          title: dashboard.approvedTherapists.toString(),
                          radius: 72,
                          color: Colors.green,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          value: dashboard.pendingTherapists.toDouble(),
                          title: dashboard.pendingTherapists.toString(),
                          radius: 72,
                          color: Colors.orange,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PieChartSectionData(
                          value: dashboard.rejectedTherapists.toDouble(),
                          title: dashboard.rejectedTherapists.toString(),
                          radius: 72,
                          color: Colors.red,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _ChartLegendItem(
                      label: 'Approved',
                      value: dashboard.approvedTherapists,
                      color: Colors.green,
                    ),
                    _ChartLegendItem(
                      label: 'Pending',
                      value: dashboard.pendingTherapists,
                      color: Colors.orange,
                    ),
                    _ChartLegendItem(
                      label: 'Rejected',
                      value: dashboard.rejectedTherapists,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AppointmentStatusChart extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _AppointmentStatusChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final maxValue =
        [
          dashboard.pendingAppointments,
          dashboard.completedAppointments,
          dashboard.cancelledAppointments,
          dashboard.otherAppointments,
        ].fold<int>(
          0,
          (currentMax, value) => value > currentMax ? value : currentMax,
        );

    if (dashboard.totalAppointments == 0) {
      return const _DashboardChartCard(
        title: 'Appointment status',
        subtitle: 'Appointments grouped by current status',
        child: _EmptyChart(message: 'No appointment data.'),
      );
    }

    final chartMaximum = maxValue <= 0 ? 1.0 : maxValue * 1.25;

    return _DashboardChartCard(
      title: 'Appointment status',
      subtitle: 'Appointments grouped by current status',
      child: SizedBox(
        height: 330,
        child: BarChart(
          BarChartData(
            maxY: chartMaximum,
            alignment: BarChartAlignment.spaceAround,
            barTouchData: BarTouchData(enabled: true),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 11),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) {
                    final label = switch (value.toInt()) {
                      0 => 'Pending',
                      1 => 'Completed',
                      2 => 'Cancelled',
                      3 => 'Other',
                      _ => '',
                    };

                    return SideTitleWidget(
                      meta: meta,
                      space: 10,
                      child: Text(label, style: const TextStyle(fontSize: 11)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              _createBarGroup(
                x: 0,
                value: dashboard.pendingAppointments,
                color: Colors.orange,
              ),
              _createBarGroup(
                x: 1,
                value: dashboard.completedAppointments,
                color: Colors.green,
              ),
              _createBarGroup(
                x: 2,
                value: dashboard.cancelledAppointments,
                color: Colors.red,
              ),
              _createBarGroup(
                x: 3,
                value: dashboard.otherAppointments,
                color: Colors.blueGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static BarChartGroupData _createBarGroup({
    required int x,
    required int value,
    required Color color,
  }) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value.toDouble(),
          width: 28,
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        ),
      ],
      showingTooltipIndicators: const [],
    );
  }
}

class _AdditionalStatistics extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _AdditionalStatistics({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final totalTherapists = dashboard.totalTherapists;

    final approvalPercentage = totalTherapists == 0
        ? 0.0
        : dashboard.approvedTherapists / totalTherapists;

    final completedPercentage = dashboard.totalAppointments == 0
        ? 0.0
        : dashboard.completedAppointments / dashboard.totalAppointments;

    final averageRevenuePerPayment = dashboard.totalPayments == 0
        ? 0.0
        : dashboard.totalRevenue / dashboard.totalPayments;

    final currencyFormatter = NumberFormat.currency(
      locale: 'bs_BA',
      symbol: 'KM',
      decimalDigits: 2,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance overview',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Calculated indicators based on current dashboard data.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 900;

                final items = [
                  _ProgressStatistic(
                    title: 'Therapist approval rate',
                    value: approvalPercentage,
                    valueLabel:
                        '${(approvalPercentage * 100).toStringAsFixed(1)}%',
                  ),
                  _ProgressStatistic(
                    title: 'Appointment completion rate',
                    value: completedPercentage,
                    valueLabel:
                        '${(completedPercentage * 100).toStringAsFixed(1)}%',
                  ),
                  _TextStatistic(
                    title: 'Average revenue per payment',
                    value: currencyFormatter.format(averageRevenuePerPayment),
                  ),
                ];

                if (!horizontal) {
                  return Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        items[index],
                        if (index != items.length - 1)
                          const SizedBox(height: 24),
                      ],
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      Expanded(child: items[index]),
                      if (index != items.length - 1) const SizedBox(width: 24),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressStatistic extends StatelessWidget {
  final String title;
  final double value;
  final String valueLabel;

  const _ProgressStatistic({
    required this.title,
    required this.value,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: safeValue,
          minHeight: 9,
          borderRadius: BorderRadius.circular(10),
        ),
        const SizedBox(height: 8),
        Text(
          valueLabel,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _TextStatistic extends StatelessWidget {
  final String title;
  final String value;

  const _TextStatistic({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _DashboardChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DashboardChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ChartLegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          '$label: $value',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;

  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart,
              size: 54,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InlineErrorMessage extends StatelessWidget {
  final String message;

  const _InlineErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  final String message;

  final Future<void> Function() onRetry;

  const _DashboardErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Dashboard could not be loaded',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    onPressed: () {
                      onRetry();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
