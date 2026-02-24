import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const String _themeKey = "is_dark_mode";
  static const Color lightPrimary = Color(0xFF7C4DFF);
  static const Color lightSecondary = Color(0xFFB388FF);
  static const Color lightScaffold = Color(0xFFF5F3FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF616161);
  static const Color lightInactiveIcons = Color(0xFF9E9E9E);
  static const Color lightSuccess = Color(0xFF4CAF50);
  static const Color lightError = Color(0xFFEF5350);

  static const Color darkPrimary = Color(0xFF9C6BFF);
  static const Color darkSecondary = Color(0xFFC9A8FF);
  static const Color darkScaffold = Color(0xFF121018);
  static const Color darkSurface = Color(0xFF1E1A2B);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFBDBDBD);
  static const Color darkInactiveIcons = Color(0xFF777777);
  static const Color darkSuccess = Color(0xFF66BB6A);
  static const Color darkError = Color(0xFFEF5350);

  // Define your light and dark themes
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: Colors.white,
      secondary: lightSecondary,
      onSecondary: lightTextPrimary,
      error: lightError,
      onError: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
    ),
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightScaffold,
    cardColor: lightSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Brightness.dark, // dark icons visible on light bg
        statusBarBrightness: Brightness.light, // iOS
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: lightSurface,
      selectedItemColor: lightPrimary,
      unselectedItemColor: lightInactiveIcons,
      showUnselectedLabels: true,
    ),
    iconTheme: const IconThemeData(color: lightTextSecondary),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
    ),
    fontFamily: 'Inter',
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: Colors.white,
      secondary: darkSecondary,
      onSecondary: darkTextPrimary,
      error: darkError,
      onError: Colors.white,
      surface: darkSurface,
      onSurface: darkTextPrimary,
    ),
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkScaffold,
    cardColor: darkSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Brightness.light, // light icons visible on dark bg
        statusBarBrightness: Brightness.dark, // iOS
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSurface,
      selectedItemColor: darkPrimary,
      unselectedItemColor: darkInactiveIcons,
      showUnselectedLabels: true,
    ),
    iconTheme: const IconThemeData(color: darkTextSecondary),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextSecondary),
    ),
    fontFamily: 'Inter',
  );

  // Save theme preference
  static Future<void> saveTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
    print("💾 Theme saved: ${isDark ? 'Dark' : 'Light'}");
  }

  // Load theme preference
  static Future<bool> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_themeKey) ?? false; // default to light
    print("📂 Theme loaded: ${isDark ? 'Dark' : 'Light'}");
    return isDark;
  }

  // Toggle and save
  static Future<void> toggleTheme(BuildContext context) async {
    final current = Theme.of(context).brightness == Brightness.dark;
    await saveTheme(!current);

    // If using Provider or setState in MyApp, rebuild
    // Here we assume you'll trigger rebuild via setState in MyApp
  }
}
