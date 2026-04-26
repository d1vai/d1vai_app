import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontFamilyDisplay = 'SmileySans';
  static const String fontFamilyBody = '.SF UI Text'; // System font fallback

  static TextTheme getTheme(bool isDark) {
    final Color primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color secondaryColor = isDark
        ? primaryColor.withValues(alpha: 0.78)
        : primaryColor.withValues(alpha: 0.72);
    final Color tertiaryColor = isDark
        ? primaryColor.withValues(alpha: 0.62)
        : primaryColor.withValues(alpha: 0.56);

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
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        letterSpacing: -0.1,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: primaryColor,
        height: 1.45,
        letterSpacing: 0.15,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondaryColor,
        height: 1.45,
        letterSpacing: 0.1,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: tertiaryColor,
        height: 1.35,
        letterSpacing: 0.15,
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
        color: tertiaryColor,
        letterSpacing: 0.25,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: tertiaryColor,
        letterSpacing: 0.2,
      ),
    );
  }
}
