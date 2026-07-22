import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/router/app_router.dart';
import '../../../appointment/presentation/pages/my_appointments_page.dart';
import '../../../dashboard/presentation/pages/client_dashboard_page.dart';
import '../../../journal/presentation/pages/journal_page.dart';
import '../../../notification/presentation/viewmodels/notification_scope.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../session/presentation/viewmodels/session_scope.dart';
import '../../../therapist/presentation/pages/therapist_list_page.dart';

class ClientNavigationShell extends StatefulWidget {
  const ClientNavigationShell({super.key});

  @override
  State<ClientNavigationShell> createState() => _ClientNavigationShellState();
}

class _ClientNavigationShellState extends State<ClientNavigationShell> {
  static const String _activeTabKey = 'mindbloom_client_active_navigation_tab';

  int currentIndex = 0;

  final List<Widget> _pages = const [
    ClientDashboardPage(),
    TherapistListPage(),
    MyAppointmentsPage(),
    JournalPage(),
    ProfilePage(),
  ];

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
    _loadActiveTab();
  }

  Future<void> _loadActiveTab() async {
    final preferences = await SharedPreferences.getInstance();

    final savedIndex = preferences.getInt(_activeTabKey);

    if (!mounted) {
      return;
    }

    if (savedIndex != null && savedIndex >= 0 && savedIndex < _pages.length) {
      setState(() {
        currentIndex = savedIndex;
      });
    }
  }

  Future<void> _changeTab(int index) async {
    if (index == currentIndex) {
      return;
    }

    setState(() {
      currentIndex = index;
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

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationScope.of(context);

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
                      Text(
                        'MindBloom',
                        style: TextStyle(
                          color: Color(0xFF5C477B),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
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
    children: _pages,
  ),
),
        bottomNavigationBar: NavigationBar(
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
