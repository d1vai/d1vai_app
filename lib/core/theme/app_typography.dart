import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamilyDisplay = 'SmileySans';
  static const String fontFamilyBody = '.SF UI Text'; // System font fallback

  static TextTheme getTheme(bool isDark) {
    final Color primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color secondaryColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return TextTheme(
      // Display / Headings (SmileySans)
      displayLarge: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontSize: 57,
        height: 1.1,
        color: primaryColor,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontSize: 45,
        height: 1.1,
        color: primaryColor,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontSize: 36,
        height: 1.1,
        color: primaryColor,
      ),
      headlineLarge: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontSize: 32,
        height: 1.2,
        color: primaryColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontSize: 28,
        height: 1.2,
        color: primaryColor,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamilyDisplay,
        fontSize: 24,
        height: 1.2,
        color: primaryColor,
      ),

      // Body / Content (System Font)
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primaryColor,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        letterSpacing: 0.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryColor, // Slightly muted for body text
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        letterSpacing: 0.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: secondaryColor,
        letterSpacing: 0.5,
      ),
    );
  }
}
