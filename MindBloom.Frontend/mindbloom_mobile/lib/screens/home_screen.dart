import 'package:flutter/material.dart';

import '../app/router/app_router.dart';
import '../features/notification/presentation/viewmodels/notification_scope.dart';
import '../features/session/presentation/viewmodels/session_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _notificationInitializationRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final session = SessionScope.of(context);

    final notifications = NotificationScope.of(context);

    if (session.isInitialized &&
        session.isLoggedIn &&
        !_notificationInitializationRequested) {
      _notificationInitializationRequested = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifications.initialize();
      });
    }
  }

  Future<void> _logout() async {
    final session = SessionScope.of(context);

    final notifications = NotificationScope.of(context);

    await notifications.stop();

    await session.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
  }

  void _openNotifications() {
    Navigator.of(context).pushNamed(AppRouter.notifications);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);

    final notifications = NotificationScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MindBloom'),
        actions: [
          if (session.isLoggedIn)
            IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: Badge.count(
                count: notifications.unreadCount,
                isLabelVisible: notifications.unreadCount > 0,
                child: const Icon(Icons.notifications),
              ),
            ),
          if (session.isLoggedIn)
            IconButton(
              tooltip: 'Logout',
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: session.isInitialized
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),
                  Text(
                    session.isLoggedIn
                        ? 'Welcome to MindBloom'
                        : 'You are not logged in.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (session.isLoggedIn) const SizedBox(height: 24),

                  if (session.isLoggedIn)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.clientDashboard);
                      },
                      child: const Text('My dashboard'),
                    ),

                  const SizedBox(height: 12),

                  if (session.isLoggedIn)
                    ElevatedButton.icon(
                      onPressed: _openNotifications,
                      icon: Badge.count(
                        count: notifications.unreadCount,
                        isLabelVisible: notifications.unreadCount > 0,
                        child: const Icon(Icons.notifications),
                      ),
                      label: Text(
                        notifications.unreadCount == 0
                            ? 'Notifications'
                            : 'Notifications '
                                  '(${notifications.unreadCount} unread)',
                      ),
                    ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.therapists);
                    },
                    child: const Text('Browse therapists'),
                  ),

                  const SizedBox(height: 12),

                  if (session.isLoggedIn)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.myFavorites);
                      },
                      icon: const Icon(Icons.favorite),
                      label: const Text('My favorites'),
                    ),

                  const SizedBox(height: 12),

                  if (session.isLoggedIn)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.myAppointments);
                      },
                      child: const Text('My appointments'),
                    ),

                  const SizedBox(height: 12),

                  if (session.isLoggedIn)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed(AppRouter.myMemberships);
                      },
                      icon: const Icon(Icons.card_membership),
                      label: const Text('My memberships'),
                    ),

                  const SizedBox(height: 12),

                  if (session.isLoggedIn)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.myPayments);
                      },
                      child: const Text('Payment history'),
                    ),

                  const SizedBox(height: 12),

                  if (session.isLoggedIn)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.profile);
                      },
                      child: const Text('My profile'),
                    ),

                  const SizedBox(height: 12),

                  if (session.isLoggedIn)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.journal);
                      },
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Journal'),
                    ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.articles);
                    },
                    icon: const Icon(Icons.article),
                    label: const Text('Articles'),
                  ),
                  if (session.isLoggedIn)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.chats);
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Messages'),
                    ),

                  if (session.isLoggedIn) const SizedBox(height: 12),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed(AppRouter.workshops);
                    },
                    icon: const Icon(Icons.groups),
                    label: const Text('Workshops'),
                  ),

                  const SizedBox(height: 12),

                  if (!session.isLoggedIn)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRouter.login);
                      },
                      child: const Text('Login'),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
