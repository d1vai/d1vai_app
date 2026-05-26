import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

enum AppLiquidGlassVariant { navigation, floating }

class AppLiquidGlass extends StatelessWidget {
  final Widget child;
  final AppLiquidGlassVariant variant;
  final double borderRadius;
  final double glowIntensity;
  final bool useOwnLayer;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;
  final GlassQuality quality;
  final LiquidGlassSettings? settings;

  const AppLiquidGlass({
    super.key,
    required this.child,
    this.variant = AppLiquidGlassVariant.floating,
    this.borderRadius = 20,
    this.glowIntensity = 0,
    this.useOwnLayer = false,
    this.width,
    this.height,
    this.margin,
    this.clipBehavior = Clip.antiAlias,
    this.quality = GlassQuality.standard,
    this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: width,
      height: height,
      margin: margin,
      clipBehavior: clipBehavior,
      quality: quality,
      glowIntensity: glowIntensity,
      useOwnLayer: useOwnLayer,
      shape: borderRadius <= 0
          ? const LiquidRoundedRectangle(borderRadius: 0)
          : LiquidRoundedSuperellipse(borderRadius: borderRadius),
      settings: settings ?? _settingsFor(context, variant),
      child: child,
    );
  }

  LiquidGlassSettings _settingsFor(
    BuildContext context,
    AppLiquidGlassVariant variant,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    switch (variant) {
      case AppLiquidGlassVariant.navigation:
        return LiquidGlassSettings(
          blur: isDark ? 14 : 10,
          thickness: isDark ? 28 : 22,
          glassColor: Color.lerp(
            colorScheme.surface.withValues(alpha: isDark ? 0.20 : 0.28),
            colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
            0.32,
          )!,
          lightIntensity: isDark ? 0.22 : 0.28,
          saturation: isDark ? 1.16 : 1.08,
          glowIntensity: isDark ? 0.42 : 0.22,
          standardOpacityMultiplier: isDark ? 1.0 : 0.72,
        );
      case AppLiquidGlassVariant.floating:
        return LiquidGlassSettings(
          blur: isDark ? 18 : 12,
          thickness: isDark ? 32 : 26,
          glassColor: Color.lerp(
            colorScheme.surface.withValues(alpha: isDark ? 0.22 : 0.26),
            colorScheme.primaryContainer.withValues(
              alpha: isDark ? 0.16 : 0.10,
            ),
            0.42,
          )!,
          lightIntensity: isDark ? 0.24 : 0.32,
          saturation: isDark ? 1.20 : 1.10,
          glowIntensity: isDark ? 0.5 : 0.26,
          standardOpacityMultiplier: isDark ? 1.0 : 0.7,
        );
    }
  }
}
