import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme {
    const background = Color(0xFFFCFAFF);
    const surface = Color(0xFFFFFFFF);
    const lavender = Color(0xFFF6F0FC);
    const lavenderStrong = Color(0xFFE9DFFF);
    const border = Color(0xFFE7DDF1);
    const primary = Color(0xFF6D4F91);
    const primaryAlt = Color(0xFF72559A);
    const text = Color(0xFF372D45);
    const muted = Color(0xFF6C6278);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: surface,
          primaryContainer: lavenderStrong,
          onPrimaryContainer: primary,
          secondary: primaryAlt,
          onSecondary: surface,
          secondaryContainer: lavender,
          onSecondaryContainer: text,
          surface: surface,
          onSurface: text,
          surfaceContainerLowest: background,
          surfaceContainerLow: surface,
          surfaceContainer: surface,
          surfaceContainerHigh: lavender,
          surfaceContainerHighest: lavender,
          onSurfaceVariant: muted,
          outline: border,
          outlineVariant: border,
          error: const Color(0xFFB42318),
          errorContainer: const Color(0xFFFFE4E2),
          onErrorContainer: const Color(0xFF7A271A),
        );

    final baseTextTheme = Typography.material2021().black.apply(
      bodyColor: text,
      displayColor: text,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      textTheme: baseTextTheme.copyWith(
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: text,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: text,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: text,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: muted),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: surface,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          side: const BorderSide(color: border),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: primary,
          hoverColor: lavender,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lavender,
        selectedColor: lavenderStrong,
        disabledColor: lavender.withValues(alpha: 0.55),
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: text, fontWeight: FontWeight.w700),
        secondaryLabelStyle: const TextStyle(
          color: primary,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          color: text,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: muted),
      ),
    );
  }
}
