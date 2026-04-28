import 'package:flutter/material.dart';

// Dark mode removed — app is light-only with blue brand colour.
class ThemeProvider extends ChangeNotifier {
  bool get isDark => false;
  ThemeMode get themeMode => ThemeMode.light;

  // toggle() kept so call-sites compile without changes
  Future<void> toggle() async {}

  // ── Light ThemeData ───────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
          primary: const Color(0xFF1A73E8),
        ),
        primaryColor: const Color(0xFF1A73E8),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF111111),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: Color(0xFF111111)),
          titleTextStyle: TextStyle(
            color: Color(0xFF111111),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFEAEAEA),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF0F2F5),
          border: InputBorder.none,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1A73E8),
          unselectedItemColor: Color(0xFF9E9E9E),
          elevation: 0,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
      );

  // darkTheme alias — returns lightTheme so nothing breaks
  static ThemeData get darkTheme => lightTheme;
}
