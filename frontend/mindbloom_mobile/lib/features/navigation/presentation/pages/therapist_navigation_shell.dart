import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/debug/mindbloom_debug_log.dart';
import '../../../appointment/presentation/pages/therapist_appointments_page.dart';
import '../../../chat/presentation/pages/chat_list_page.dart';
import '../../../notification/presentation/viewmodels/notification_scope.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../../../therapist/presentation/pages/therapist_clients_page.dart';
import '../../../therapist/presentation/pages/therapist_dashboard_page.dart';
import '../../../../app/di/injection.dart';

class TherapistNavigationShell extends StatefulWidget {
  const TherapistNavigationShell({super.key});

  @override
  State<TherapistNavigationShell> createState() =>
      _TherapistNavigationShellState();
}

class _TherapistNavigationShellState extends State<TherapistNavigationShell> {
  static const String _activeTabKey =
      'mindbloom_therapist_active_navigation_tab';
  static const int _pageCount = 4;

  int currentIndex = 0;

  final Set<int> _visitedIndexes = <int>{0};

  final List<String> _titles = const ['Početna', 'Termini', 'Klijenti', 'Chat'];

  @override
  void initState() {
    super.initState();

    logWidget('TherapistNavigationShell.initState');

    _loadActiveTab();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyNotificationSettings();
    });
  }

  Future<void> _applyNotificationSettings() async {
    final stopwatch = Stopwatch()..start();

    logWidget('TherapistNavigationShell.notificationSettings started');

    try {
      final repository = AppInjection.createUserSettingsRepository();

      final settings = await repository.getSettings();

      if (!mounted) {
        return;
      }

      final notifications = NotificationScope.read(context);

      if (settings.notificationsEnabled) {
        logWidget('TherapistNavigationShell notifications enabled');
        await notifications.initialize();
      } else {
        logWidget('TherapistNavigationShell notifications disabled');
        await notifications.stop();
      }
    } catch (error) {
      logWidget(
        'TherapistNavigationShell.notificationSettings failed '
        '${error.runtimeType}: $error',
      );
      // Notifications keep their current behavior if settings cannot be loaded.
    } finally {
      logWidget(
        'TherapistNavigationShell.notificationSettings finished '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }

  Future<void> _loadActiveTab() async {
    final preferences = await SharedPreferences.getInstance();

    final savedIndex = preferences.getInt(_activeTabKey);

    if (!mounted) {
      return;
    }

    if (savedIndex != null && savedIndex >= 0 && savedIndex < _pageCount) {
      setState(() {
        currentIndex = savedIndex;
        _visitedIndexes.add(savedIndex);
      });
    }
  }

  Future<void> _changeTab(int index) async {
    if (index == currentIndex) {
      return;
    }

    setState(() {
      currentIndex = index;
      _visitedIndexes.add(index);
    });

    final preferences = await SharedPreferences.getInstance();

    await preferences.setInt(_activeTabKey, index);
  }

  Future<void> _logout() async {
    final session = SessionScope.of(context);
    final notifications = NotificationScope.of(context);

    await notifications.stop();
    await session.logout();

    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_activeTabKey);

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  void _openRoute(String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  void _openDrawerRoute(String routeName) {
    Navigator.of(context).pop();

    Navigator.of(context).pushNamed(routeName);
  }

  Future<void> _handleDrawerLogout() async {
    Navigator.of(context).pop();

    await _logout();
  }

  Widget _buildPage(int index) {
    if (!_visitedIndexes.contains(index)) {
      return const SizedBox.shrink();
    }

    return switch (index) {
      0 => const TherapistDashboardPage(),
      1 => const TherapistAppointmentsPage(),
      2 => const TherapistClientsPage(),
      3 => const ChatListPage(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationScope.of(context);

    logWidget(
      'TherapistNavigationShell.build currentIndex=$currentIndex '
      'unreadCount=${notifications.unreadCount}',
    );

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (currentIndex != 0) {
          _changeTab(0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[currentIndex]),
          actions: [
            IconButton(
              tooltip: 'Notifikacije',
              onPressed: () {
                _openRoute(AppRouter.notifications);
              },
              icon: Badge.count(
                count: notifications.unreadCount,
                isLabelVisible: notifications.unreadCount > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFFE9DFFF),
                        child: Icon(
                          Icons.local_florist_outlined,
                          color: Color(0xFF72559A),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'MindBloom terapeut',
                          style: TextStyle(
                            color: Color(0xFF5C477B),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.dashboard_outlined),
                        title: const Text('Kontrolna ploča'),
                        onTap: () {
                          Navigator.of(context).pop();
                          _changeTab(0);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_outlined),
                        title: const Text('Notifikacije'),
                        trailing: notifications.unreadCount > 0
                            ? Badge.count(count: notifications.unreadCount)
                            : null,
                        onTap: () {
                          _openDrawerRoute(AppRouter.notifications);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Profil'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.profile);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Postavke'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.therapistSettings);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: const Text('Članci'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.articles);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: const Text('Radionice'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.workshops);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('O nama'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.about);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Odjava'),
                  onTap: _handleDrawerLogout,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: IndexedStack(
            index: currentIndex,
            children: List.generate(_pageCount, _buildPage),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: _changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Početna',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Termini',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Klijenti',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: 'Chat',
            ),
          ],
        ),
      ),
    );
  }
}
