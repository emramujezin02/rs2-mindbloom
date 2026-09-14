import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/therapist_dashboard_model.dart';
import '../viewmodels/therapist_dashboard_viewmodel.dart';

const _dashboardBackground = Color(0xFFF7F3FB);
const _dashboardSurface = Color(0xFFFFFFFF);
const _dashboardLavender = Color(0xFFF6F0FC);
const _dashboardMint = Color(0xFFEAF7F4);
const _dashboardBorder = Color(0xFFE7DDF1);
const _dashboardPrimary = Color(0xFF6D4F91);
const _dashboardAccent = Color(0xFF6FA8A2);
const _dashboardText = Color(0xFF372D45);
const _dashboardMuted = Color(0xFF6C6278);
const _dashboardRadius = 22.0;

class TherapistDashboardPage extends StatefulWidget {
  const TherapistDashboardPage({super.key});

  @override
  State<TherapistDashboardPage> createState() => _TherapistDashboardPageState();
}

class _TherapistDashboardPageState extends State<TherapistDashboardPage> {
  late final TherapistDashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createTherapistDashboardViewModel();

    _viewModel.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _viewModel.loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openAppointments() {
    Navigator.of(context).pushNamed(AppRouter.therapistAppointments);
  }

  void _openClients() {
    Navigator.of(context).pushNamed(AppRouter.therapistClients);
  }

  void _openProfile() {
    Navigator.of(context).pushNamed(AppRouter.profile);
  }

  void _openAvailability() {
    Navigator.of(context).pushNamed(AppRouter.profile);
  }

  void _openChat() {
    Navigator.of(context).pushNamed(AppRouter.chats);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashboardBackground,
      body: RefreshIndicator(
        onRefresh: _viewModel.refresh,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.dashboard == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Učitavanje kontrolne ploče...',
        skeletonItemCount: 7,
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.dashboard == null) {
      return AppErrorWidget(
        title: 'Kontrolnu ploču nije moguće učitati',
        error: _viewModel.errorMessage,
        onRetry: _viewModel.loadDashboard,
      );
    }

    final dashboard = _viewModel.dashboard;

    if (dashboard == null) {
      return const AppEmptyStateWidget(
        title: 'Kontrolna ploča nije dostupna',
        message: 'Podaci kontrolne ploče trenutno nisu dostupni.',
        icon: Icons.dashboard_outlined,
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_viewModel.errorMessage != null) ...[
                  AppInlineError(
                    title: 'Podaci nisu mogli biti osvježeni',
                    error: _viewModel.errorMessage,
                    onRetry: _viewModel.refresh,
                  ),
                  const SizedBox(height: 16),
                ],
                _WelcomeCard(dashboard: dashboard),
                const SizedBox(height: 22),
                _DashboardStatistics(dashboard: dashboard),
                const SizedBox(height: 26),
                _WorkTrendSection(workTrend: dashboard.workTrend),
                const SizedBox(height: 26),
                _QuickActions(
                  onAppointments: _openAppointments,
                  onClients: _openClients,
                  onProfile: _openProfile,
                  onAvailability: _openAvailability,
                  onChat: _openChat,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final TherapistDashboardModel dashboard;

  const _WelcomeCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_dashboardPrimary, Color(0xFF8063A4)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _dashboardPrimary.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.local_florist_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const Spacer(),
              _HeroPill(
                icon: Icons.mark_chat_unread_outlined,
                label: '${dashboard.unreadMessages} poruka',
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Dobro došli',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dashboard.todayAppointments == 0
                ? 'Danas nemate zakazanih termina. Iskoristite prostor za pripremu, klijente i poruke.'
                : 'Danas imate ${dashboard.todayAppointments} termina i ${dashboard.upcomingAppointments} nadolazećih obaveza.',
            style: const TextStyle(
              color: Color(0xFFF4EDF8),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(
                icon: Icons.today_outlined,
                label: '${dashboard.todayAppointments} danas',
              ),
              _HeroPill(
                icon: Icons.people_outline,
                label: '${dashboard.activeClients} aktivnih klijenata',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardStatistics extends StatelessWidget {
  final TherapistDashboardModel dashboard;

  const _DashboardStatistics({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final primaryCards = [
      _DashboardCardData(
        title: 'Današnji termini',
        value: dashboard.todayAppointments.toString(),
        icon: Icons.today_outlined,
        tone: _MetricTone.mint,
      ),
      _DashboardCardData(
        title: 'Nadolazeći termini',
        value: dashboard.upcomingAppointments.toString(),
        icon: Icons.event_available_outlined,
        tone: _MetricTone.lavender,
      ),
      _DashboardCardData(
        title: 'Aktivni klijenti',
        value: dashboard.activeClients.toString(),
        icon: Icons.groups_2_outlined,
        tone: _MetricTone.mint,
      ),
      _DashboardCardData(
        title: 'Prosječna ocjena',
        value: dashboard.averageRating.toStringAsFixed(1),
        icon: Icons.star_outline,
        tone: _MetricTone.gold,
      ),
    ];

    final secondaryCards = [
      _DashboardCardData(
        title: 'Ukupan broj klijenata',
        value: dashboard.totalClients.toString(),
        icon: Icons.people_outline,
      ),
      _DashboardCardData(
        title: 'Novi klijenti ovog mjeseca',
        value: dashboard.newClients.toString(),
        icon: Icons.person_add_alt_1_outlined,
      ),
      _DashboardCardData(
        title: 'Novi zahtjevi',
        value: dashboard.newRequests.toString(),
        icon: Icons.pending_actions_outlined,
      ),
      _DashboardCardData(
        title: 'Nepročitane poruke',
        value: dashboard.unreadMessages.toString(),
        icon: Icons.mark_chat_unread_outlined,
      ),
      _DashboardCardData(
        title: 'Prosjek termina mjesečno',
        value: dashboard.averageAppointmentsPerMonth.toStringAsFixed(1),
        icon: Icons.analytics_outlined,
      ),
      _DashboardCardData(
        title: 'Završeni termini',
        value: dashboard.completedAppointments.toString(),
        icon: Icons.task_alt_outlined,
      ),
      _DashboardCardData(
        title: 'Otkazani termini',
        value: dashboard.cancelledAppointments.toString(),
        icon: Icons.event_busy_outlined,
      ),
      _DashboardCardData(
        title: 'Ukupna zarada',
        value: '${dashboard.totalEarnings.toStringAsFixed(2)} KM',
        icon: Icons.payments_outlined,
      ),
      _DashboardCardData(
        title: 'Mjesečna zarada',
        value: '${dashboard.monthlyEarnings.toStringAsFixed(2)} KM',
        icon: Icons.calendar_month_outlined,
      ),
      _DashboardCardData(
        title: 'Sedmična zarada',
        value: '${dashboard.weeklyEarnings.toStringAsFixed(2)} KM',
        icon: Icons.date_range_outlined,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Pregled',
          subtitle: 'Aktuelni podaci vaše terapeutske prakse.',
        ),
        const SizedBox(height: 16),
        _ResponsiveGrid(
          minItemWidth: 148,
          spacing: 12,
          children: primaryCards
              .map((card) => _DashboardCard(data: card, isPrimary: true))
              .toList(),
        ),
        const SizedBox(height: 12),
        _ResponsiveGrid(
          minItemWidth: 156,
          spacing: 12,
          children: secondaryCards
              .map((card) => _DashboardCard(data: card))
              .toList(),
        ),
      ],
    );
  }
}

class _WorkTrendSection extends StatelessWidget {
  final List<TherapistWorkTrendModel> workTrend;

  const _WorkTrendSection({required this.workTrend});

  @override
  Widget build(BuildContext context) {
    final maximumAppointments = workTrend.isEmpty
        ? 0
        : workTrend
              .map((item) => item.completedAppointments)
              .reduce((current, next) => current > next ? current : next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Trend rada',
          subtitle: 'Broj završenih termina tokom posljednjih šest mjeseci.',
        ),
        const SizedBox(height: 16),
        _DashboardSurface(
          child: workTrend.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bar_chart_outlined,
                        size: 42,
                        color: _dashboardPrimary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Podaci o trendu rada nisu dostupni.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _dashboardMuted),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var index = 0; index < workTrend.length; index++) ...[
                      _WorkTrendRow(
                        item: workTrend[index],
                        progress: maximumAppointments == 0
                            ? 0
                            : workTrend[index].completedAppointments /
                                  maximumAppointments,
                      ),
                      if (index != workTrend.length - 1)
                        const SizedBox(height: 14),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _WorkTrendRow extends StatelessWidget {
  final TherapistWorkTrendModel item;
  final double progress;

  const _WorkTrendRow({required this.item, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _dashboardText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 12,
              color: _dashboardLavender,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: _dashboardAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 34,
          child: Text(
            item.completedAppointments.toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: _dashboardPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onAppointments;
  final VoidCallback onClients;
  final VoidCallback onProfile;
  final VoidCallback onAvailability;
  final VoidCallback onChat;

  const _QuickActions({
    required this.onAppointments,
    required this.onClients,
    required this.onProfile,
    required this.onAvailability,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickActionData(
        title: 'Moji termini',
        icon: Icons.calendar_month_outlined,
        onTap: onAppointments,
      ),
      _QuickActionData(
        title: 'Klijenti',
        icon: Icons.people_outline,
        onTap: onClients,
      ),
      _QuickActionData(
        title: 'Profil',
        icon: Icons.person_outline,
        onTap: onProfile,
      ),
      _QuickActionData(
        title: 'Dostupnost',
        icon: Icons.schedule_outlined,
        onTap: onAvailability,
      ),
      _QuickActionData(title: 'Chat', icon: Icons.chat_outlined, onTap: onChat),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Brze akcije',
          subtitle: 'Brzo otvorite najčešće korištene sekcije.',
        ),
        const SizedBox(height: 16),
        _ResponsiveGrid(
          minItemWidth: 136,
          spacing: 12,
          children: actions
              .map((action) => _QuickActionCard(data: action))
              .toList(),
        ),
      ],
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final _DashboardCardData data;
  final bool isPrimary;

  const _DashboardCard({required this.data, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    final palette = data.tone.palette;

    return _DashboardSurface(
      padding: EdgeInsets.all(isPrimary ? 16 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isPrimary ? 42 : 38,
                height: isPrimary ? 42 : 38,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, color: palette.foreground, size: 22),
              ),
              const Spacer(),
              if (isPrimary)
                Icon(
                  Icons.trending_flat,
                  color: palette.foreground.withValues(alpha: 0.72),
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashboardText,
              fontSize: isPrimary ? 25 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _dashboardMuted,
              fontSize: isPrimary ? 13 : 12,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionData data;

  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _dashboardSurface,
      borderRadius: BorderRadius.circular(_dashboardRadius),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(_dashboardRadius),
        child: Container(
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_dashboardRadius),
            border: Border.all(color: _dashboardBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _dashboardLavender,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(data.icon, size: 23, color: _dashboardPrimary),
              ),
              const SizedBox(height: 10),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _dashboardText,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  const _ResponsiveGrid({
    required this.children,
    required this.minItemWidth,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minItemWidth)
            .floor()
            .clamp(1, 3);

        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _DashboardSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DashboardSurface({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _dashboardSurface,
        borderRadius: BorderRadius.circular(_dashboardRadius),
        border: Border.all(color: _dashboardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: _dashboardText,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _dashboardMuted,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCardData {
  final String title;
  final String value;
  final IconData icon;
  final _MetricTone tone;

  const _DashboardCardData({
    required this.title,
    required this.value,
    required this.icon,
    this.tone = _MetricTone.lavender,
  });
}

class _QuickActionData {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

enum _MetricTone {
  lavender,
  mint,
  gold;

  _MetricPalette get palette {
    return switch (this) {
      _MetricTone.lavender => const _MetricPalette(
        background: _dashboardLavender,
        foreground: _dashboardPrimary,
      ),
      _MetricTone.mint => const _MetricPalette(
        background: _dashboardMint,
        foreground: Color(0xFF3E8F86),
      ),
      _MetricTone.gold => const _MetricPalette(
        background: Color(0xFFFFF4D8),
        foreground: Color(0xFFB7791F),
      ),
    };
  }
}

class _MetricPalette {
  final Color background;
  final Color foreground;

  const _MetricPalette({
    required this.background,
    required this.foreground,
  });
}
