import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/client_dashboard_model.dart';
import '../viewmodels/client_dashboard_viewmodel.dart';

const _homeBackground = Color(0xFFFCFAFF);
const _homeLavender = Color(0xFFF5EFFC);
const _homeSurface = Color(0xFFFFFFFF);
const _homeBorder = Color(0xFFE8DEF3);
const _homePrimary = Color(0xFF6D4F91);
const _homeText = Color(0xFF3E3152);
const _homeBody = Color(0xFF625B6B);
const _homeRadius = 20.0;

class ClientDashboardPage extends StatefulWidget {
  final bool showAppBar;

  const ClientDashboardPage({super.key, this.showAppBar = true});

  @override
  State<ClientDashboardPage> createState() => _ClientDashboardPageState();
}

class _ClientDashboardPageState extends State<ClientDashboardPage> {
  final ClientDashboardViewModel _viewModel =
      AppInjection.createClientDashboardViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.loadDashboard();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final body = ColoredBox(
      color: _homeBackground,
      child: SafeArea(top: false, child: _buildBody(formatter)),
    );

    if (!widget.showAppBar) {
      return body;
    }

    return Scaffold(
      backgroundColor: _homeBackground,
      appBar: AppBar(title: const Text('My dashboard')),
      body: body,
    );
  }

  Widget _buildBody(DateFormat formatter) {
    final dashboard = _viewModel.dashboard;

    if (_viewModel.isLoading && dashboard == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading dashboard...',
        skeletonItemCount: 6,
      );
    }

    if (_viewModel.error != null && dashboard == null) {
      return AppErrorWidget(
        title: 'Dashboard could not be loaded',
        error: _viewModel.error,
        onRetry: _viewModel.refresh,
      );
    }

    if (dashboard == null) {
      return RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: const AppEmptyStateWidget(
          title: 'Dashboard unavailable',
          message: 'Dashboard data is currently unavailable.',
          icon: Icons.dashboard_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Dashboard could not be refreshed',
              error: _viewModel.error,
              onRetry: _viewModel.refresh,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          _HomeHeroPanel(dashboard: dashboard, formatter: formatter),
          const SizedBox(height: 18),
          _HomeSection(
            title: 'Quick access',
            child: Column(
              children: [
                _HomeActionTile(
                  icon: Icons.auto_awesome,
                  title: 'Recommended therapists',
                  subtitle: 'View therapists recommended specifically for you.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.recommendations);
                  },
                ),
                const SizedBox(height: 10),
                _HomeActionTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Private journal',
                  subtitle: 'Write and manage private journal entries.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRouter.privateJournal);
                  },
                ),
                const SizedBox(height: 10),
                _HomeActionTile(
                  icon: Icons.insights,
                  title: 'My emotional patterns',
                  subtitle:
                      'View mood trends and your most frequently recorded emotions.',
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pushNamed(AppRouter.clientEmotionalAnalytics);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _HomeSection(
            title: 'Care summary',
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 520 ? 2 : 1;
                const spacing = 10.0;
                final itemWidth =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    _DashboardMetricCard(
                      icon: Icons.calendar_month,
                      title: 'Total appointments',
                      value: dashboard.totalAppointments.toString(),
                      width: itemWidth,
                    ),
                    _DashboardMetricCard(
                      icon: Icons.check_circle,
                      title: 'Completed appointments',
                      value: dashboard.completedAppointments.toString(),
                      width: itemWidth,
                    ),
                    _DashboardMetricCard(
                      icon: Icons.schedule,
                      title: 'Pending appointments',
                      value: dashboard.pendingAppointments.toString(),
                      width: itemWidth,
                    ),
                    _DashboardMetricCard(
                      icon: Icons.cancel,
                      title: 'Cancelled appointments',
                      value: dashboard.cancelledAppointments.toString(),
                      width: itemWidth,
                    ),
                    _DashboardMetricCard(
                      icon: Icons.psychology,
                      title: 'Therapists visited',
                      value: dashboard.totalTherapistsVisited.toString(),
                      width: itemWidth,
                    ),
                    _DashboardMetricCard(
                      icon: Icons.payments,
                      title: 'Total spent',
                      value: '${dashboard.totalSpent.toStringAsFixed(2)} KM',
                      width: itemWidth,
                    ),
                    _DashboardMetricCard(
                      icon: Icons.history,
                      title: 'Last appointment',
                      value: dashboard.lastAppointmentDate == null
                          ? 'No previous appointments'
                          : formatter.format(
                              dashboard.lastAppointmentDate!.toLocal(),
                            ),
                      width: itemWidth,
                    ),
                    _DashboardMetricCard(
                      icon: Icons.event_available,
                      title: 'Next appointment',
                      value: dashboard.nextAppointmentDate == null
                          ? 'No upcoming appointments'
                          : formatter.format(
                              dashboard.nextAppointmentDate!.toLocal(),
                            ),
                      width: itemWidth,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeroPanel extends StatelessWidget {
  final ClientDashboardModel dashboard;
  final DateFormat formatter;

  const _HomeHeroPanel({required this.dashboard, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final nextAppointment = dashboard.nextAppointmentDate;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _homeLavender,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _homeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE9DFFF),
                child: Icon(Icons.local_florist_outlined, color: _homePrimary),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Welcome back',
                  style: TextStyle(
                    color: _homeText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            nextAppointment == null
                ? 'No upcoming appointment is scheduled yet.'
                : 'Next appointment: ${formatter.format(nextAppointment.toLocal())}',
            style: const TextStyle(
              color: _homeBody,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroStat(
                label: 'Completed',
                value: dashboard.completedAppointments.toString(),
              ),
              _HeroStat(
                label: 'Therapists',
                value: dashboard.totalTherapistsVisited.toString(),
              ),
              _HeroStat(
                label: 'Spent',
                value: '${dashboard.totalSpent.toStringAsFixed(2)} KM',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;

  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 94),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _homeText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _homeBody,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _HomeSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            title,
            style: const TextStyle(
              color: _homeText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _homeSurface,
      borderRadius: BorderRadius.circular(_homeRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_homeRadius),
            border: Border.all(color: _homeBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9DFFF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _homePrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _homeText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _homeBody, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: _homePrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double width;

  const _DashboardMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _homeSurface,
          borderRadius: BorderRadius.circular(_homeRadius),
          border: Border.all(color: _homeBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _homeLavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _homePrimary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _homeBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _homeText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
