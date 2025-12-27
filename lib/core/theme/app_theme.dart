import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const String _themeKey = "is_dark_mode";

  // Define your light and dark themes
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF8743F4),
    scaffoldBackgroundColor: const Color.fromARGB(255, 230, 230, 250),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: Color(0xFF8743F4),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
    ),
    fontFamily: 'Inter',
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF8743F4),
    scaffoldBackgroundColor: const Color(0xFF171022),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF171022),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF171022),
      selectedItemColor: Color(0xFF8743F4),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
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