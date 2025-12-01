import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.lightPrimary,
        onPrimary: Colors.white,
        secondary: AppColors.lightSecondary,
        onSecondary: Colors.white,
        error: AppColors.lightError,
        onError: Colors.white,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightTextPrimary,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
        bodyMedium: TextStyle(color: AppColors.lightTextSecondary),
        bodySmall: TextStyle(color: AppColors.lightTextSecondary),
        labelLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: AppColors.lightTextSecondary),
        labelSmall: TextStyle(color: AppColors.lightTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkSurface,
        secondary: AppColors.darkSecondary,
        onSecondary: Colors.white,
        error: AppColors.lightError,
        onError: Colors.white,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkSecondary, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
        bodyMedium: TextStyle(color: AppColors.darkTextSecondary),
        bodySmall: TextStyle(color: AppColors.darkTextSecondary),
        labelLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: AppColors.darkTextSecondary),
        labelSmall: TextStyle(color: AppColors.darkTextSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkSecondary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkSecondary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 2),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.darkPrimary,
        foregroundColor: AppColors.darkSurface,
      ),
    );
  }
}
