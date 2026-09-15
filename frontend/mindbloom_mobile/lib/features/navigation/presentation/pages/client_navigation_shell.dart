import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/debug/mindbloom_debug_log.dart';
import '../../../appointment/presentation/pages/my_appointments_page.dart';
import '../../../dashboard/presentation/pages/client_dashboard_page.dart';
import '../../../notification/presentation/viewmodels/notification_scope.dart';
import '../../../private_journal/presentation/pages/private_journal_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../../../therapist/presentation/pages/therapist_list_page.dart';

const _shellBackground = Color(0xFFFCFAFF);
const _shellSurface = Color(0xFFFFFFFF);
const _shellLavender = Color(0xFFF5EFFC);
const _shellBorder = Color(0xFFE8DEF3);
const _shellPrimary = Color(0xFF6D4F91);
const _shellText = Color(0xFF3E3152);

class ClientNavigationShell extends StatefulWidget {
  const ClientNavigationShell({super.key});

  @override
  State<ClientNavigationShell> createState() => _ClientNavigationShellState();
}

class _ClientNavigationShellState extends State<ClientNavigationShell> {
  static const String _activeTabKey = 'mindbloom_client_active_navigation_tab';
  static const int _pageCount = 5;

  int currentIndex = 0;

  final Set<int> _visitedIndexes = <int>{0};

  final List<String> _titles = const [
    'Početna',
    'Terapeuti',
    'Termini',
    'Dnevnik',
    'Profil',
  ];

  @override
  void initState() {
    super.initState();
    logWidget('ClientNavigationShell.initState');
    _loadActiveTab();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      logWidget('ClientNavigationShell starting notifications.initialize');
      unawaited(NotificationScope.read(context).initialize());
    });
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

  Widget _buildPage(int index) {
    if (!_visitedIndexes.contains(index)) {
      return const SizedBox.shrink();
    }

    return switch (index) {
      0 => const ClientDashboardPage(showAppBar: false),
      1 => const TherapistListPage(showAppBar: false),
      2 => const MyAppointmentsPage(),
      3 => const PrivateJournalPage(),
      4 => const ProfilePage(),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _handleDrawerLogout() async {
    Navigator.of(context).pop();

    await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationScope.of(context);

    logWidget(
      'ClientNavigationShell.build currentIndex=$currentIndex '
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
        backgroundColor: _shellBackground,
        appBar: AppBar(
          title: Text(_titles[currentIndex]),
          backgroundColor: _shellBackground,
          foregroundColor: _shellText,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'Chat',
              onPressed: () {
                _openRoute(AppRouter.chats);
              },
              icon: const Icon(Icons.chat_outlined),
            ),
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
          backgroundColor: _shellBackground,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _shellSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _shellBorder),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFFE9DFFF),
                          child: Icon(
                            Icons.local_florist_outlined,
                            color: _shellPrimary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'MindBloom',
                          style: TextStyle(
                            color: _shellPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const Text('Chat'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.chats);
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
                        leading: const Icon(Icons.article_outlined),
                        title: const Text('Članci'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.articles);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: const Text('Preporučeni terapeuti'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.recommendations);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.favorite_outline),
                        title: const Text('Omiljeni terapeuti'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.myFavorites);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.card_membership_outlined),
                        title: const Text('Moje članstvo'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.myMemberships);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: const Text('Plaćanja'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.myPayments);
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
                        leading: const Icon(Icons.reviews_outlined),
                        title: const Text('Moje recenzije'),
                        onTap: () {
                          _openDrawerRoute(AppRouter.myReviews);
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
          backgroundColor: _shellSurface,
          indicatorColor: _shellLavender,
          surfaceTintColor: Colors.transparent,
          selectedIndex: currentIndex,
          onDestinationSelected: _changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Početna',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_alt_outlined),
              selectedIcon: Icon(Icons.psychology_alt),
              label: 'Terapeuti',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Termini',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Dnevnik',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
