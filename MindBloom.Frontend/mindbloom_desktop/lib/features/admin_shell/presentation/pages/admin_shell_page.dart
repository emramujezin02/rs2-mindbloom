import 'package:flutter/material.dart';
import 'package:mindbloom_desktop/features/appointment_management/presentation/pages/appointment_managemenet_page.dart';
import 'package:mindbloom_desktop/features/reports/presentation/pages/appointment_revenue_report_page.dart';
import 'package:mindbloom_desktop/features/reports/presentation/pages/therapist_performance_report_page.dart';
import 'package:mindbloom_desktop/features/therapist_verification/presentation/pages/therapist_verification_page.dart';
import 'package:mindbloom_desktop/features/users/presentation/pages/users_page.dart';
import '../../../review_moderation/presentation/pages/review_moderation_page.dart';
import '../../../../app/router/app_router.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../../data/models/admin_section.dart';
import '../../../payment_management/presentation/pages/payment_management_page.dart';
import '../../../membership_management/presentation/pages/membership_management_page.dart';
import '../../../article_management/presentation/pages/article_management_page.dart';
import '../../../workshop_management/presentation/pages/workshop_management_page.dart';
import '../../../reference_data/presentation/pages/reference_data_management_page.dart';

class AdminShellPage extends StatefulWidget {
  final AdminSection initialSection;

  const AdminShellPage({
    super.key,
    this.initialSection = AdminSection.dashboard,
  });

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  static const double _desktopBreakpoint = 1000;

  late AdminSection _selectedSection;

  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();

    _selectedSection = widget.initialSection;
  }

  void _selectSection(AdminSection section) {
    if (_selectedSection == section) {
      return;
    }

    setState(() {
      _selectedSection = section;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to sign out of the MindBloom admin application?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final session = SessionScope.of(context);

    await session.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  void _handleBackNavigation() {
    if (_selectedSection == AdminSection.dashboard) {
      return;
    }

    setState(() {
      _selectedSection = AdminSection.dashboard;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    return PopScope(
      canPop: _selectedSection == AdminSection.dashboard,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBackNavigation();
      },
      child: Scaffold(
        drawer: isDesktop
            ? null
            : Drawer(
                child: SafeArea(
                  child: _AdminSidebar(
                    selectedSection: _selectedSection,
                    expanded: true,
                    onSectionSelected: (section) {
                      _selectSection(section);

                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
        body: SafeArea(
          child: Row(
            children: [
              if (isDesktop)
                _AdminSidebar(
                  selectedSection: _selectedSection,
                  expanded: _isSidebarExpanded,
                  onSectionSelected: _selectSection,
                ),
              Expanded(
                child: Column(
                  children: [
                    Builder(
                      builder: (topbarContext) {
                        return _AdminTopbar(
                          title: _selectedSection.title,
                          isDesktop: isDesktop,
                          isSidebarExpanded: _isSidebarExpanded,
                          onMenuPressed: isDesktop
                              ? _toggleSidebar
                              : () {
                                  Scaffold.of(topbarContext).openDrawer();
                                },
                          onLogoutPressed: _logout,
                        );
                      },
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLowest,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _buildSelectedPage(),
                        ),
                      ),
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

  Widget _buildSelectedPage() {
    switch (_selectedSection) {
      case AdminSection.dashboard:
        return const DashboardPage(key: ValueKey(AdminSection.dashboard));

      case AdminSection.users:
        return const UsersPage(key: ValueKey(AdminSection.users));

      case AdminSection.therapists:
        return const TherapistVerificationPage(
          key: ValueKey(AdminSection.therapists),
        );

      case AdminSection.appointments:
        return const AppointmentManagementPage(
          key: ValueKey(AdminSection.appointments),
        );

      case AdminSection.payments:
        return const PaymentManagementPage(
          key: ValueKey(AdminSection.payments),
        );

      case AdminSection.memberships:
        return const MembershipManagementPage(
          key: ValueKey(AdminSection.memberships),
        );

      case AdminSection.workshops:
        return const WorkshopManagementPage(
          key: ValueKey(AdminSection.workshops),
        );

      case AdminSection.articles:
        return const ArticleManagementPage();

      case AdminSection.reviews:
        return const ReviewModerationPage(key: ValueKey(AdminSection.reviews));

      case AdminSection.referenceData:
        return const ReferenceDataManagementPage(
          key: ValueKey(AdminSection.referenceData),
        );

      case AdminSection.appointmentRevenueReport:
        return const AppointmentRevenueReportPage(
          key: ValueKey(AdminSection.appointmentRevenueReport),
        );

      case AdminSection.therapistPerformanceReport:
        return const TherapistPerformanceReportPage(
          key: ValueKey(AdminSection.therapistPerformanceReport),
        );
    }
  }
}

class _AdminSidebar extends StatelessWidget {
  final AdminSection selectedSection;

  final bool expanded;

  final ValueChanged<AdminSection> onSectionSelected;

  const _AdminSidebar({
    required this.selectedSection,
    required this.expanded,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final width = expanded ? 250.0 : 82.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 14),
              child: Row(
                mainAxisAlignment: expanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.spa,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'MindBloom',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              children: AdminSection.values.map((section) {
                final isSelected = section == selectedSection;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Tooltip(
                    message: expanded ? '' : section.title,
                    child: Material(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          onSectionSelected(section);
                        },
                        child: SizedBox(
                          height: 50,
                          child: Row(
                            mainAxisAlignment: expanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: expanded ? 48 : 60,
                                child: Icon(
                                  isSelected
                                      ? section.selectedIcon
                                      : section.icon,
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer
                                      : null,
                                ),
                              ),
                              if (expanded)
                                Expanded(
                                  child: Text(
                                    section.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimaryContainer
                                          : null,
                                    ),
                                  ),
                                ),
                              if (expanded) const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          if (expanded)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'MindBloom Administration',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AdminTopbar extends StatelessWidget {
  final String title;

  final bool isDesktop;

  final bool isSidebarExpanded;

  final VoidCallback onMenuPressed;

  final Future<void> Function() onLogoutPressed;

  const _AdminTopbar({
    required this.title,
    required this.isDesktop,
    required this.isSidebarExpanded,
    required this.onMenuPressed,
    required this.onLogoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    final currentUser = session.currentUser;

    final email = currentUser?.email ?? 'Administrator';

    final username = currentUser?.username.trim() ?? '';

    final displayName = username.isNotEmpty ? username : email;

    final initial = displayName.trim().isEmpty
        ? 'A'
        : displayName.trim()[0].toUpperCase();

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: isDesktop
                ? isSidebarExpanded
                      ? 'Collapse sidebar'
                      : 'Expand sidebar'
                : 'Open navigation',
            onPressed: onMenuPressed,
            icon: Icon(
              isDesktop
                  ? isSidebarExpanded
                        ? Icons.menu_open
                        : Icons.menu
                  : Icons.menu,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          if (MediaQuery.sizeOf(context).width >= 700) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  email,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          CircleAvatar(child: Text(initial)),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Account menu',
            onSelected: (value) {
              if (value == 'logout') {
                onLogoutPressed();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 12),
                      Text('Logout'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}
