import 'package:flutter/material.dart';

import '../features/session/session_scope.dart';
import '../features/session/session_viewmodel.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class MindBloomDesktopApp extends StatelessWidget {
  final SessionViewModel session;

  const MindBloomDesktopApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: session,
      child: MaterialApp(
        title: 'MindBloom Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: AppRouter.root,
      ),
    );
  }
}
