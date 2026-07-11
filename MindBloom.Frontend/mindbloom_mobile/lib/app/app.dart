import 'package:flutter/material.dart';
import '../features/session/presentation/session_scope.dart';
import '../features/session/presentation/viewmodels/session_viewmodel.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/navigation/app_navigation.dart';

class MindBloomMobileApp extends StatelessWidget {
  final SessionViewModel session;

  const MindBloomMobileApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: MaterialApp(
        navigatorKey: AppNavigation.navigatorKey,
        title: 'MindBloom',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: AppRouter.home,
      ),
    );
  }
}
