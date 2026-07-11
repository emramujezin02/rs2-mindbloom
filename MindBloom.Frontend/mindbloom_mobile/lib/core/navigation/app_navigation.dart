import 'package:flutter/material.dart';

class AppNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void goToLogin() {
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      return;
    }

    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
