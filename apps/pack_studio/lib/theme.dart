import 'package:flutter/material.dart';

/// The d30mode palette (read off the game's main menu), so Pack Studio looks
/// like it belongs to the same family.
class StudioColors {
  static const page = Color(0xFFFFF3E2);
  static const paper = Color(0xFFFFFAE9);
  static const rule = Color(0xFFFFEEDB);
  static const panel = Color(0xFFFFF8EC);
  static const panelBorder = Color(0xFFF3C58E);
  static const outline = Color(0xFFF5B08A);
  static const accent = Color(0xFFFF8B55);
  static const accentDark = Color(0xFFE2761F);
  static const ink = Color(0xFF4A3B2E);
  static const inkSoft = Color(0xFF8A7765);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: StudioColors.accent,
    surface: StudioColors.panel,
    primary: StudioColors.accentDark,
    onSurface: StudioColors.ink,
  ),
  scaffoldBackgroundColor: StudioColors.page,
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: StudioColors.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
);
