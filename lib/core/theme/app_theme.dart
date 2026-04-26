import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  // Private constructor
  AppTheme._();

  static ThemeData get light {
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
      textTheme: AppTypography.getTheme(false),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppTypography.getTheme(
          false,
        ).bodyMedium?.copyWith(color: AppColors.textSecondaryLight),
        hintStyle: AppTypography.getTheme(false).bodySmall?.copyWith(
          color: AppColors.textSecondaryLight.withValues(alpha: 0.9),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTypography.getTheme(false).titleSmall,
        subtitleTextStyle: AppTypography.getTheme(false).bodySmall,
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

  static ThemeData get dark {
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
      textTheme: AppTypography.getTheme(true),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: AppTypography.getTheme(
          true,
        ).bodyMedium?.copyWith(color: AppColors.textSecondaryDark),
        hintStyle: AppTypography.getTheme(true).bodySmall?.copyWith(
          color: AppColors.textSecondaryDark.withValues(alpha: 0.9),
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppTypography.getTheme(true).titleSmall,
        subtitleTextStyle: AppTypography.getTheme(true).bodySmall,
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
