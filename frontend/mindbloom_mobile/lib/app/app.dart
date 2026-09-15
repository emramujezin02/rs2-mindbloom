import 'package:flutter/material.dart';

import '../core/navigation/app_navigation.dart';
import '../core/debug/mindbloom_debug_log.dart';
import '../features/notification/presentation/viewmodels/notification_scope.dart';
import '../features/notification/presentation/viewmodels/notification_viewmodel.dart';
import '../features/session/presentation/viewmodels/session_scope.dart';
import '../features/session/presentation/viewmodels/session_viewmodel.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MindBloomMobileApp extends StatelessWidget {
  final SessionViewModel session;

  final NotificationViewModel notificationViewModel;

  const MindBloomMobileApp({
    super.key,
    required this.session,
    required this.notificationViewModel,
  });

  @override
  Widget build(BuildContext context) {
    logStartup('MindBloomMobileApp.build reached');

    return SessionScope(
      session: session,
      child: NotificationScope(
        notificationViewModel: notificationViewModel,
        child: MaterialApp(
          navigatorKey: AppNavigation.navigatorKey,
          title: 'MindBloom',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: AppRouter.home,
          builder: (context, child) {
            logStartup(
              'MaterialApp.builder reached child=${child.runtimeType}',
            );

            return child ?? const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
