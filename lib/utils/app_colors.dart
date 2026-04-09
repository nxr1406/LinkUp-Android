import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ──────────────────────────────────────────────────────
  static const Color primary      = Color(0xFFE91E8C);
  static const Color primaryLight = Color(0xFFF06292);
  static const Color primaryDark  = Color(0xFFC2185B);
  static const Color verified     = Color(0xFFE91E8C);  // pink — same as primary
  static const Color messageBubble = Color(0xFFE91E8C); // pink

  // ── Light theme ────────────────────────────────────────────────
  static const Color background   = Color(0xFFF5F5F5);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color black        = Color(0xFF1A1A2E);
  static const Color grey         = Color(0xFF9E9E9E);
  static const Color greyLight    = Color(0xFFEEEEEE);
  static const Color textDark     = Color(0xFF212121);
  static const Color textMedium   = Color(0xFF757575);

  // ── Dark theme ─────────────────────────────────────────────────
  static const Color darkBackground   = Color(0xFF0F0F14);
  static const Color darkSurface      = Color(0xFF1A1A2E);
  static const Color darkCard         = Color(0xFF232338);
  static const Color darkAppBar       = Color(0xFF1A1A2E);
  static const Color darkText         = Color(0xFFF0F0F0);
  static const Color darkTextMedium   = Color(0xFFAAAAAA);
  static const Color darkDivider      = Color(0xFF2E2E45);
  static const Color darkInputFill    = Color(0xFF232338);
  static const Color darkBubbleOther  = Color(0xFF2A2A45);

  // ── Gradient ───────────────────────────────────────────────────
  static const List<Color> pinkGradient = [
    Color(0xFFE91E8C),
    Color(0xFFF06292),
    Color(0xFFEC407A),
  ];

  // ── Theme helpers ──────────────────────────────────────────────
  static Color scaffoldBg(bool dark)    => dark ? darkBackground : background;
  static Color cardBg(bool dark)        => dark ? darkCard : white;
  static Color appBarBg(bool dark)      => dark ? darkAppBar : white;
  static Color textPrimary(bool dark)   => dark ? darkText : black;
  static Color textSecondary(bool dark) => dark ? darkTextMedium : textMedium;
  static Color divider(bool dark)       => dark ? darkDivider : greyLight;
  static Color inputFill(bool dark)     => dark ? darkInputFill : white;
  static Color bubbleOther(bool dark)   => dark ? darkBubbleOther : const Color(0xFFFCE4EC); // light pink tint
}
