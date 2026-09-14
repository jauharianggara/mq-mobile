import 'package:flutter/material.dart';

/// MQ Brand Colors — hijau + gold (konsisten mq-admin).
class AppColors {
  // Primary: hijau MQ (oklch 0.45 0.10 155)
  static const primary = Color(0xFF1B7A4E);
  static const primaryLight = Color(0xFF3D9A6E);
  static const primaryDark = Color(0xFF0F5A36);

  // Accent: gold
  static const gold = Color(0xFFC9A227);
  static const goldLight = Color(0xFFE6C84D);
  static const goldDark = Color(0xFFA88520);

  // Neutral
  static const background = Color(0xFFF8FAF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF0F4F0);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF1A1C1A);
  static const onSurfaceVariant = Color(0xFF5F6B5F);

  // Status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  // Dark mode
  static const darkBackground = Color(0xFF0F1A12);
  static const darkSurface = Color(0xFF1A2B1E);
  static const darkSurfaceVariant = Color(0xFF253628);
  static const darkOnSurface = Color(0xFFE0E8E0);
}

/// MQ Theme — Material 3.
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.gold,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
  }
}
