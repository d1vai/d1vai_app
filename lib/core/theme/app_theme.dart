import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  // Private constructor
  AppTheme._();

  static ThemeData light(Locale? locale) {
    final textTheme = AppTypography.getTheme(false, locale: locale);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors
            .surfaceDark, // Using dark surface as primary for contrast in light mode
        onPrimary: Colors.white,
        secondary: AppColors.success,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.error,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderLight,
      ),
      scaffoldBackgroundColor: AppColors.surfaceLight,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondaryLight,
        ),
        hintStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondaryLight.withValues(alpha: 0.9),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
    );
  }

  static ThemeData dark(Locale? locale) {
    final textTheme = AppTypography.getTheme(true, locale: locale);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBrand, // Brand color pops in dark mode
        onPrimary: Colors.white,
        secondary: AppColors.secondaryBrand,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        error: AppColors.error,
        outline: AppColors.borderDark,
        outlineVariant: AppColors.borderDark,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondaryDark,
        ),
        hintStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondaryDark.withValues(alpha: 0.9),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
      ),
    );
  }
}
