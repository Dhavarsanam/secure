import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const primary = Color(0xFF1A73E8);
  static const primaryDark = Color(0xFF1557B0);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const purple = Color(0xFF7C3AED);

  // Light theme
  static const lightBg = Color(0xFFF5F7FA);
  static const lightCard = Colors.white;
  static const lightText = Color(0xFF1A1A2E);
  static const lightSubText = Color(0xFF6B7280);
  static const lightBorder = Color(0xFFE5E7EB);

  // Dark theme
  static const darkBg = Color(0xFF0F0F1A);
  static const darkCard = Color(0xFF1A1A2E);
  static const darkCard2 = Color(0xFF252538);
  static const darkText = Color(0xFFF1F5F9);
  static const darkSubText = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF2D2D44);
}

class AppTheme {
  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
    scaffoldBackgroundColor: AppColors.lightBg,
    cardTheme: CardThemeData(color: AppColors.lightCard, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, centerTitle: false),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Colors.white, selectedItemColor: AppColors.primary, unselectedItemColor: AppColors.lightSubText, elevation: 8, type: BottomNavigationBarType.fixed),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: AppColors.lightBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.lightBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.lightBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2))),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
    fontFamily: 'Roboto',
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark),
    scaffoldBackgroundColor: AppColors.darkBg,
    cardTheme: CardThemeData(color: AppColors.darkCard, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1A1A2E), foregroundColor: Colors.white, elevation: 0, centerTitle: false),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Color(0xFF1A1A2E), selectedItemColor: AppColors.primary, unselectedItemColor: Color(0xFF94A3B8), elevation: 8, type: BottomNavigationBarType.fixed),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: AppColors.darkCard2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.darkBorder)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.darkBorder)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2))),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
    fontFamily: 'Roboto',
  );
}
