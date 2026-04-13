import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'isDarkMode';
  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
  }

  // ── Light ThemeData ──────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E8C),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A2E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFEEEEEE),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: InputBorder.none,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1A1A2E),
          unselectedItemColor: Color(0xFF9E9E9E),
          elevation: 0,
        ),
      );

  // ── Dark ThemeData — pure black ─────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E8C),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A0A0A),
          onSurface: const Color(0xFFF0F0F0),
        ),
        scaffoldBackgroundColor: const Color(0xFF000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF000000),
          foregroundColor: Color(0xFFF0F0F0),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFF0F0F0)),
          titleTextStyle: TextStyle(
            color: Color(0xFFF0F0F0),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardColor: const Color(0xFF111111),
        dividerColor: const Color(0xFF1E1E1E),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF111111),
          border: InputBorder.none,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF000000),
          selectedItemColor: Color(0xFFF0F0F0),
          unselectedItemColor: Color(0xFF777777),
          elevation: 0,
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
          textColor: Color(0xFFF0F0F0),
          iconColor: Color(0xFFF0F0F0),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF111111),
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF111111),
          surfaceTintColor: Colors.transparent,
        ),
      );
}
