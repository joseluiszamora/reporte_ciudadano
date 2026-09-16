import 'package:flutter/material.dart';

abstract final class AppSpace {
  static const double small = 8;
  static const double medium = 16;
  static const double large = 24;
  static const double section = 32;
}

abstract final class AppColors {
  static const primary = Color(0xFF1D4ED8);
  static const ink = Color(0xFF0F172A);
  static const secondary = Color(0xFF475569);
  static const background = Color(0xFFF8FAFC);
  static const border = Color(0xFFCBD5E1);
  static const field = Color(0xFF64748B);
  static const soft = Color(0xFFEFF6FF);
  static const warning = Color(0xFF92400E);
  static const warningBackground = Color(0xFFFFFBEB);
  static const success = Color(0xFF166534);
  static const successBackground = Color(0xFFF0FDF4);
}

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.secondary,
    outline: AppColors.field,
    error: const Color(0xFFB91C1C),
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 28 / 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 16, height: 1.5),
    bodySmall: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      color: AppColors.secondary,
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.ink,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.border),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: AppColors.soft,
  ),
);
