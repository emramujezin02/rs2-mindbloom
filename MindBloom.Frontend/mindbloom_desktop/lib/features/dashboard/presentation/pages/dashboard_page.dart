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
  late final AdminDashboardViewModel _viewModel;

  final DateFormat _dateFormatter = DateFormat('dd.MM.yyyy');

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'bs_BA',
    symbol: 'KM',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createAdminDashboardViewModel();

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

  Future<void> _selectFromDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _viewModel.fromDate,
      firstDate: DateTime(2020),
      lastDate: _viewModel.toDate,
      helpText: 'Select dashboard start date',
    );

    if (selectedDate == null) {
      return;
    }

    _viewModel.setCustomFromDate(selectedDate);
  }

  Future<void> _selectToDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _viewModel.toDate,
      firstDate: _viewModel.fromDate,
      lastDate: DateTime.now(),
      helpText: 'Select dashboard end date',
    );

    if (selectedDate == null) {
      return;
    }

    _viewModel.setCustomToDate(selectedDate);
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
            _buildHeader(),

            const SizedBox(height: 22),

            _buildPeriodFilter(),

            if (_viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              _InlineErrorMessage(message: _viewModel.errorMessage!),
            ],

            const SizedBox(height: 28),

            if (!dashboard.hasAnyData)
              const _DashboardEmptyState()
            else ...[
              _buildSummaryCards(dashboard),

              const SizedBox(height: 28),

              _buildStatusCharts(dashboard),

              const SizedBox(height: 28),

              _buildTimelineCharts(dashboard),
              const SizedBox(height: 28),

              _buildAdditionalAnalyticsCharts(dashboard),

              const SizedBox(height: 28),

              _buildSystemStatistics(dashboard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final session = SessionScope.of(context);

    final currentUser = session.currentUser;

    final username = currentUser?.username.trim() ?? '';

    final email = currentUser?.email.trim() ?? '';

    final displayName = username.isNotEmpty ? username : 'Administrator';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $displayName',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              email.isEmpty
                  ? 'MindBloom system analytics'
                  : 'Signed in as $email',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        );

        final refreshButton = OutlinedButton.icon(
          onPressed: _viewModel.isLoading ? null : _refresh,
          icon: _viewModel.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(_viewModel.isLoading ? 'Refreshing...' : 'Refresh'),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [title, const SizedBox(height: 16), refreshButton],
          );
        }

        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 20),
            refreshButton,
          ],
        );
      },
    );
  }

  Widget _buildPeriodFilter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 900;

            final periodDropdown =
                DropdownButtonFormField<AdminDashboardPeriod>(
                  initialValue: _viewModel.selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Period',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  items: AdminDashboardPeriod.values.map((period) {
                    return DropdownMenuItem(
                      value: period,
                      child: Text(period.label),
                    );
                  }).toList(),
                  onChanged: _viewModel.isLoading
                      ? null
                      : (period) {
                          if (period != null) {
                            _viewModel.setPeriod(period);
                          }
                        },
                );

            final fromField = _DateField(
              label: 'From date',
              value: _dateFormatter.format(_viewModel.fromDate),
              enabled: !_viewModel.isLoading,
              onPressed: _selectFromDate,
            );

            final toField = _DateField(
              label: 'To date',
              value: _dateFormatter.format(_viewModel.toDate),
              enabled: !_viewModel.isLoading,
              onPressed: _selectToDate,
            );

            final applyButton = ElevatedButton.icon(
              onPressed: _viewModel.isLoading ? null : _viewModel.loadDashboard,
              icon: const Icon(Icons.filter_alt),
              label: const Text('Apply period'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  periodDropdown,
                  const SizedBox(height: 14),
                  fromField,
                  const SizedBox(height: 14),
                  toField,
                  const SizedBox(height: 16),
                  applyButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: periodDropdown),
                const SizedBox(width: 14),
                Expanded(child: fromField),
                const SizedBox(width: 14),
                Expanded(child: toField),
                const SizedBox(width: 18),
                applyButton,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(AdminDashboardModel dashboard) {
    final cards = [
      _SummaryData(
        icon: Icons.people,
        title: 'Total users',
        value: dashboard.totalUsers.toString(),
        description: '${dashboard.activeClients} active clients',
      ),
      _SummaryData(
        icon: Icons.person_outline,
        title: 'Active clients',
        value: dashboard.activeClients.toString(),
        description: 'Active client accounts',
      ),
      _SummaryData(
        icon: Icons.psychology,
        title: 'Therapists',
        value: dashboard.totalTherapists.toString(),
        description: '${dashboard.verifiedTherapists} verified',
      ),
      _SummaryData(
        icon: Icons.verified,
        title: 'Verified therapists',
        value: dashboard.verifiedTherapists.toString(),
        description: 'Approved profiles',
      ),
      _SummaryData(
        icon: Icons.pending_actions,
        title: 'Pending therapists',
        value: dashboard.pendingTherapists.toString(),
        description: 'Awaiting verification',
        warning: dashboard.pendingTherapists > 0,
      ),
      _SummaryData(
        icon: Icons.calendar_month,
        title: 'Appointments',
        value: dashboard.totalAppointments.toString(),
        description: '${dashboard.todayAppointments} today',
      ),
      _SummaryData(
        icon: Icons.today,
        title: 'Today appointments',
        value: dashboard.todayAppointments.toString(),
        description: 'Scheduled for today',
      ),
      _SummaryData(
        icon: Icons.task_alt,
        title: 'Completed',
        value: dashboard.completedAppointments.toString(),
        description: 'Selected period',
      ),
      _SummaryData(
        icon: Icons.event_busy,
        title: 'Cancelled',
        value: dashboard.cancelledAppointments.toString(),
        description: 'Cancelled or rejected',
      ),
      _SummaryData(
        icon: Icons.account_balance_wallet,
        title: 'Total revenue',
        value: _currencyFormatter.format(dashboard.totalRevenue),
        description: 'All paid transactions',
      ),
      _SummaryData(
        icon: Icons.calendar_view_month,
        title: 'Monthly revenue',
        value: _currencyFormatter.format(dashboard.currentMonthRevenue),
        description: 'Current calendar month',
      ),
      _SummaryData(
        icon: Icons.analytics,
        title: 'Period revenue',
        value: _currencyFormatter.format(dashboard.periodRevenue),
        description: 'Selected period',
      ),
      _SummaryData(
        icon: Icons.card_membership,
        title: 'Active memberships',
        value: dashboard.activeMemberships.toString(),
        description: 'Paid and usable',
      ),
      _SummaryData(
        icon: Icons.rate_review,
        title: 'Pending reviews',
        value: dashboard.pendingReviews.toString(),
        description: 'Awaiting moderation',
        warning: dashboard.pendingReviews > 0,
      ),
      _SummaryData(
        icon: Icons.article,
        title: 'Published articles',
        value: dashboard.publishedArticles.toString(),
        description: 'Currently published',
      ),
      _SummaryData(
        icon: Icons.groups,
        title: 'Active workshops',
        value: dashboard.activeWorkshops.toString(),
        description: 'Scheduled workshops',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 1300
            ? 4
            : constraints.maxWidth >= 820
            ? 2
            : 1;

        const spacing = 16.0;

        final width =
            (constraints.maxWidth - ((columnCount - 1) * spacing)) /
            columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return _DashboardSummaryCard(width: width, data: card);
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatusCharts(AdminDashboardModel dashboard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final appointments = _AppointmentStatusChart(dashboard: dashboard);

        final therapists = _TherapistVerificationChart(dashboard: dashboard);

        if (constraints.maxWidth < 1050) {
          return Column(
            children: [appointments, const SizedBox(height: 18), therapists],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: appointments),
            const SizedBox(width: 18),
            Expanded(child: therapists),
          ],
        );
      },
    );
  }

  Widget _buildTimelineCharts(AdminDashboardModel dashboard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final revenue = _RevenueByMonthChart(
          dashboard: dashboard,
          formatter: _currencyFormatter,
        );

        final users = _NewUsersByMonthChart(dashboard: dashboard);

        if (constraints.maxWidth < 1050) {
          return Column(children: [revenue, const SizedBox(height: 18), users]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: revenue),
            const SizedBox(width: 18),
            Expanded(child: users),
          ],
        );
      },
    );
  }

  Widget _buildAdditionalAnalyticsCharts(AdminDashboardModel dashboard) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final therapyApproaches = _AppointmentsByTherapyApproachChart(
          dashboard: dashboard,
        );

        final verifiedTherapists = _VerifiedTherapistsByMonthChart(
          dashboard: dashboard,
        );

        if (constraints.maxWidth < 1050) {
          return Column(
            children: [
              therapyApproaches,
              const SizedBox(height: 18),
              verifiedTherapists,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: therapyApproaches),
            const SizedBox(width: 18),
            Expanded(child: verifiedTherapists),
          ],
        );
      },
    );
  }

  Widget _buildSystemStatistics(AdminDashboardModel dashboard) {
    final therapistApprovalRate = dashboard.totalTherapists == 0
        ? 0.0
        : dashboard.verifiedTherapists / dashboard.totalTherapists;

    final completionRate = dashboard.totalAppointments == 0
        ? 0.0
        : dashboard.completedAppointments / dashboard.totalAppointments;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System overview',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Calculated from the current reporting response.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final items = [
                  _ProgressStatistic(
                    title: 'Therapist verification rate',
                    value: therapistApprovalRate,
                  ),
                  _ProgressStatistic(
                    title: 'Appointment completion rate',
                    value: completionRate,
                  ),
                  _TextStatistic(
                    title: 'Generated at',
                    value: DateFormat(
                      'dd.MM.yyyy HH:mm',
                    ).format(dashboard.generatedAtUtc),
                  ),
                ];

                if (constraints.maxWidth < 900) {
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

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onPressed;

  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onPressed : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month),
          enabled: enabled,
        ),
        child: Text(value),
      ),
    );
  }
}

class _SummaryData {
  final IconData icon;
  final String title;
  final String value;
  final String description;
  final bool warning;

  const _SummaryData({
    required this.icon,
    required this.title,
    required this.value,
    required this.description,
    this.warning = false,
  });
}

class _DashboardSummaryCard extends StatelessWidget {
  final double width;
  final _SummaryData data;

  const _DashboardSummaryCard({required this.width, required this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final foreground = data.warning
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    final background = data.warning
        ? colors.errorContainer
        : colors.primaryContainer;

    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: foreground),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      data.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.description,
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

class _AppointmentStatusChart extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _AppointmentStatusChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.appointmentsByStatus;

    if (items.isEmpty) {
      return const _DashboardChartCard(
        title: 'Appointments by status',
        subtitle: 'Selected reporting period',
        child: _EmptyChart(message: 'No appointment data for this period.'),
      );
    }

    final maximum = items
        .map((item) => item.count)
        .fold<int>(0, (current, value) => value > current ? value : current);

    return _DashboardChartCard(
      title: 'Appointments by status',
      subtitle: 'Selected reporting period',
      child: SizedBox(
        height: 330,
        child: BarChart(
          BarChartData(
            maxY: maximum <= 0 ? 1 : maximum * 1.25,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(drawVerticalLine: false),
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
                  reservedSize: 56,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();

                    if (index < 0 || index >= items.length) {
                      return const SizedBox();
                    }

                    return SideTitleWidget(
                      meta: meta,
                      space: 10,
                      child: SizedBox(
                        width: 70,
                        child: Text(
                          _formatLabel(items[index].label),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var index = 0; index < items.length; index++)
                BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: items[index].count.toDouble(),
                      width: 25,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistVerificationChart extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _TherapistVerificationChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final values = [
      dashboard.verifiedTherapists,
      dashboard.pendingTherapists,
      dashboard.rejectedTherapists,
    ];

    final total = values.fold<int>(0, (a, b) => a + b);

    return _DashboardChartCard(
      title: 'Therapist verification',
      subtitle: 'Current therapist profile statuses',
      child: total == 0
          ? const _EmptyChart(message: 'No therapist verification data.')
          : Column(
              children: [
                SizedBox(
                  height: 255,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 52,
                      sectionsSpace: 3,
                      sections: [
                        PieChartSectionData(
                          value: values[0].toDouble(),
                          title: values[0].toString(),
                          radius: 70,
                        ),
                        PieChartSectionData(
                          value: values[1].toDouble(),
                          title: values[1].toString(),
                          radius: 70,
                        ),
                        PieChartSectionData(
                          value: values[2].toDouble(),
                          title: values[2].toString(),
                          radius: 70,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    Text('Verified: ${values[0]}'),
                    Text('Pending: ${values[1]}'),
                    Text('Other: ${values[2]}'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RevenueByMonthChart extends StatelessWidget {
  final AdminDashboardModel dashboard;
  final NumberFormat formatter;

  const _RevenueByMonthChart({
    required this.dashboard,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final items = dashboard.revenueByMonth;

    if (items.isEmpty) {
      return const _DashboardChartCard(
        title: 'Revenue by month',
        subtitle: 'Paid transactions in selected period',
        child: _EmptyChart(message: 'No revenue data for this period.'),
      );
    }

    final maximum = items
        .map((item) => item.revenue)
        .fold<double>(0, (current, value) => value > current ? value : current);

    return _DashboardChartCard(
      title: 'Revenue by month',
      subtitle: 'Paid transactions in selected period',
      child: SizedBox(
        height: 330,
        child: BarChart(
          BarChartData(
            maxY: maximum <= 0 ? 1 : maximum * 1.25,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(drawVerticalLine: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    formatter.format(rod.toY),
                    const TextStyle(fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
            titlesData: _monthlyTitles(
              items.map((item) => item.label).toList(),
            ),
            barGroups: [
              for (var index = 0; index < items.length; index++)
                BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: items[index].revenue,
                      width: 24,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewUsersByMonthChart extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _NewUsersByMonthChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.newUsersByMonth;

    if (items.isEmpty) {
      return const _DashboardChartCard(
        title: 'New users by month',
        subtitle: 'Registrations in selected period',
        child: _EmptyChart(message: 'No new user data for this period.'),
      );
    }

    final spots = [
      for (var index = 0; index < items.length; index++)
        FlSpot(index.toDouble(), items[index].count.toDouble()),
    ];

    return _DashboardChartCard(
      title: 'New users by month',
      subtitle: 'Registrations in selected period',
      child: SizedBox(
        height: 330,
        child: LineChart(
          LineChartData(
            minY: 0,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(drawVerticalLine: false),
            titlesData: _monthlyTitles(
              items.map((item) => item.label).toList(),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

FlTitlesData _monthlyTitles(List<String> labels) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 48,
        getTitlesWidget: (value, meta) {
          return Text(
            value.toInt().toString(),
            style: const TextStyle(fontSize: 10),
          );
        },
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 44,
        getTitlesWidget: (value, meta) {
          final index = value.toInt();

          if (index < 0 || index >= labels.length) {
            return const SizedBox();
          }

          return SideTitleWidget(
            meta: meta,
            space: 10,
            child: Text(labels[index], style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    ),
  );
}

class _AppointmentsByTherapyApproachChart extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _AppointmentsByTherapyApproachChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.appointmentsByTherapyApproach;

    if (items.isEmpty) {
      return const _DashboardChartCard(
        title: 'Appointments by therapy approach',
        subtitle: 'Appointments linked to therapists offering each approach',
        child: _EmptyChart(
          message: 'No therapy approach appointment data for this period.',
        ),
      );
    }

    final maximum = items
        .map((item) => item.count)
        .fold<int>(0, (current, value) => value > current ? value : current);

    return _DashboardChartCard(
      title: 'Appointments by therapy approach',
      subtitle: 'A single appointment may appear under multiple approaches',
      child: SizedBox(
        height: 360,
        child: BarChart(
          BarChartData(
            maxY: maximum <= 0 ? 1 : maximum * 1.25,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(drawVerticalLine: false),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  if (groupIndex < 0 || groupIndex >= items.length) {
                    return null;
                  }

                  return BarTooltipItem(
                    '${items[groupIndex].label}\n'
                    '${rod.toY.toInt()} appointments',
                    const TextStyle(fontWeight: FontWeight.bold),
                  );
                },
              ),
            ),
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
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 74,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();

                    if (index < 0 || index >= items.length) {
                      return const SizedBox();
                    }

                    return SideTitleWidget(
                      meta: meta,
                      space: 10,
                      child: SizedBox(
                        width: 84,
                        child: Text(
                          items[index].label,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var index = 0; index < items.length; index++)
                BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: items[index].count.toDouble(),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedTherapistsByMonthChart extends StatelessWidget {
  final AdminDashboardModel dashboard;

  const _VerifiedTherapistsByMonthChart({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final items = dashboard.verifiedTherapistsByMonth;

    if (items.isEmpty) {
      return const _DashboardChartCard(
        title: 'Verified therapists over time',
        subtitle: 'New therapist approvals by month',
        child: _EmptyChart(message: 'No therapist approvals for this period.'),
      );
    }

    final spots = [
      for (var index = 0; index < items.length; index++)
        FlSpot(index.toDouble(), items[index].count.toDouble()),
    ];

    final maximum = items
        .map((item) => item.count)
        .fold<int>(0, (current, value) => value > current ? value : current);

    return _DashboardChartCard(
      title: 'Verified therapists over time',
      subtitle: 'New therapist approvals by month',
      child: SizedBox(
        height: 360,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: items.length == 1 ? 1 : (items.length - 1).toDouble(),
            minY: 0,
            maxY: maximum <= 0 ? 1 : maximum * 1.25,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(drawVerticalLine: false),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();

                    if (index < 0 || index >= items.length) {
                      return null;
                    }

                    return LineTooltipItem(
                      '${items[index].label}\n'
                      '${spot.y.toInt()} verified',
                      const TextStyle(fontWeight: FontWeight.bold),
                    );
                  }).toList();
                },
              ),
            ),
            titlesData: _monthlyTitles(
              items.map((item) => item.label).toList(),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: items.length > 2,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: true),
              ),
            ],
          ),
        ),
      ),
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

class _ProgressStatistic extends StatelessWidget {
  final String title;
  final double value;

  const _ProgressStatistic({required this.title, required this.value});

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
          '${(safeValue * 100).toStringAsFixed(1)}%',
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
      height: 280,
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 64),
            SizedBox(height: 16),
            Text(
              'No dashboard data available',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'There is no system activity for the selected period.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Dashboard could not be loaded',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatLabel(String value) {
  final normalized = value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll('_', ' ')
      .trim();

  if (normalized.isEmpty) {
    return 'Unknown';
  }

  return normalized[0].toUpperCase() + normalized.substring(1);
}
