import 'package:flutter/material.dart';

/// Clean, minimal, readable Material 3 design system for Article Pulse.
/// Designed for distraction-free reading without loud gradients or excessive animations.
class AppTheme {
  // Light palette: Calm slate, ivory/paper white, deep ink text
  static const Color _lightPrimary = Color(0xFF1E3A5F); // Deep slate navy
  static const Color _lightSecondary = Color(0xFF4A6B82);
  static const Color _lightBackground = Color(0xFFF8F9FA); // Off-white paper
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF1A1A1A);
  static const Color _lightTextSecondary = Color(0xFF5A6672);
  static const Color _lightCardBorder = Color(0xFFE5E9EE);

  // Dark palette: Low-contrast charcoal, slate, soft off-white text
  static const Color _darkPrimary = Color(0xFF7CA6D0);
  static const Color _darkSecondary = Color(0xFF9AB3C7);
  static const Color _darkBackground = Color(0xFF121417); // Rich dark charcoal
  static const Color _darkSurface = Color(0xFF1A1D23);
  static const Color _darkTextPrimary = Color(0xFFEAEAEA);
  static const Color _darkTextSecondary = Color(0xFFA0AAB5);
  static const Color _darkCardBorder = Color(0xFF282D36);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: _lightSecondary,
        surface: _lightSurface,
        onSurface: _lightTextPrimary,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightSurface,
        foregroundColor: _lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _lightCardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightSurface,
        elevation: 2,
        indicatorColor: _lightPrimary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _lightPrimary);
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _lightTextSecondary);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: _lightCardBorder,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _lightTextPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _lightTextPrimary,
          height: 1.3,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _lightTextSecondary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _lightTextSecondary,
          height: 1.3,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: _darkSecondary,
        surface: _darkSurface,
        onSurface: _darkTextPrimary,
        onPrimary: Color(0xFF121417),
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: _darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _darkTextPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _darkCardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkSurface,
        elevation: 2,
        indicatorColor: _darkPrimary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _darkPrimary);
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _darkTextSecondary);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: _darkCardBorder,
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: _darkTextPrimary,
          letterSpacing: -0.5,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _darkTextPrimary,
          letterSpacing: -0.3,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _darkTextPrimary,
          height: 1.3,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: _darkTextSecondary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: _darkTextSecondary,
          height: 1.3,
        ),
      ),
    );
  }
}
