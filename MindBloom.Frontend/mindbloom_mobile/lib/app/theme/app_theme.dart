import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6FA8A2)),
      scaffoldBackgroundColor: const Color(0xFFF7FAF9),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: Color(0xFFF7FAF9),
        foregroundColor: Color(0xFF1F2933),
        elevation: 0,
      ),
    );
  }
}
