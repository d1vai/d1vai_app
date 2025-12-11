import 'package:flutter/material.dart';

class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // --- Core Palette ---
  static const Color primaryBrand = Color(0xFF6366F1); // Indigo 500
  static const Color secondaryBrand = Color(0xFFEC4899); // Pink 500
  static const Color _darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color _lightBackground = Color(0xFFF8FAFC); // Slate 50

  // --- Semantic Colors ---

  // Backgrounds
  static const Color surfaceDark = _darkBackground;
  static const Color surfaceLight = _lightBackground;
  static const Color surfaceGlassDark = Color(
    0xCC1E293B,
  ); // Slate 800 with opacity
  static const Color surfaceGlassLight = Color(
    0xCCFFFFFF,
  ); // White with opacity

  // Text
  static const Color textPrimaryDark = Color(0xFFF1F5F9); // Slate 100
  static const Color textSecondaryDark = Color(0xFF94A3B8); // Slate 400
  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500

  // Status
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color error = Color(0xFFEF4444); // Red 500
  static const Color info = Color(0xFF3B82F6); // Blue 500

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryBrand, secondaryBrand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientDark = LinearGradient(
    colors: [
      Color(0x1AFFFFFF), // White 10%
      Color(0x05FFFFFF), // White 2%
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Borders
  static const Color borderDark = Color(0xFF334155); // Slate 700
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200
  static const Color borderSubtleDark = Color(0x1AFFFFFF); // White 10%
}
