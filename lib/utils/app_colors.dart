import 'package:flutter/material.dart';

class AppColors {
  // ── Brand — Blue ───────────────────────────────────────────────
  static const Color primary       = Color(0xFF1A73E8); // Google blue
  static const Color primaryLight  = Color(0xFF4A90E2);
  static const Color primaryDark   = Color(0xFF0D47A1);
  static const Color verified      = Color(0xFF1A73E8);
  static const Color messageBubble = Color(0xFF1A73E8);

  // ── Light theme (always-on) ────────────────────────────────────
  static const Color background    = Color(0xFFFFFFFF); // pure white like WA
  static const Color scaffoldColor = Color(0xFFFFFFFF);
  static const Color white         = Color(0xFFFFFFFF);
  static const Color black         = Color(0xFF111111);
  static const Color grey          = Color(0xFF9E9E9E);
  static const Color greyLight     = Color(0xFFEEEEEE);
  static const Color textDark      = Color(0xFF111111);
  static const Color textMedium    = Color(0xFF666666);
  static const Color searchBarFill = Color(0xFFF0F2F5); // WA search bar grey
  static const Color appBarColor   = Color(0xFFFFFFFF);
  static const Color dividerColor  = Color(0xFFEAEAEA);
  static const Color inputFillColor = Color(0xFFF0F2F5);
  static const Color bubbleMe      = Color(0xFFDCF8FF); // light blue bubble
  static const Color bubbleOtherColor = Color(0xFFF0F2F5);

  // ── Gradient — Blue ────────────────────────────────────────────
  static const List<Color> blueGradient = [
    Color(0xFF1A73E8),
    Color(0xFF4A90E2),
    Color(0xFF1565C0),
  ];

  // ── Theme helpers (always light, dark param kept for compat) ───
  static Color scaffoldBg(bool dark)    => scaffoldColor;
  static Color cardBg(bool dark)        => white;
  static Color appBarBg(bool dark)      => appBarColor;
  static Color textPrimary(bool dark)   => textDark;
  static Color textSecondary(bool dark) => textMedium;
  static Color divider(bool dark)       => dividerColor;
  static Color inputFill(bool dark)     => inputFillColor;
  static Color bubbleOther(bool dark)   => bubbleOtherColor;
}
