import 'package:flutter/material.dart';

import '../../screens/home_screen.dart';

class AppRouter {
  static const String home = '/';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
