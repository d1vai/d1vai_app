import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_liquid_glass.dart';

class AppGlassSurface extends StatelessWidget {
  final Widget child;
  final AppLiquidGlassVariant variant;
  final BorderRadiusGeometry borderRadius;
  final double glassBorderRadius;
  final double glowIntensity;
  final bool useOwnLayer;
  final GlassQuality quality;
  final LiquidGlassSettings? settings;
  final Decoration? overlayDecoration;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  const AppGlassSurface({
    super.key,
    required this.child,
    this.variant = AppLiquidGlassVariant.navigation,
    this.borderRadius = BorderRadius.zero,
    this.glassBorderRadius = 0,
    this.glowIntensity = 0,
    this.useOwnLayer = false,
    this.quality = GlassQuality.premium,
    this.settings,
    this.overlayDecoration,
    this.boxShadow,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedBorderRadius = borderRadius.resolve(
      Directionality.of(context),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: resolvedBorderRadius,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: resolvedBorderRadius,
        clipBehavior: clipBehavior,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: AppLiquidGlass(
                  variant: variant,
                  borderRadius: glassBorderRadius,
                  glowIntensity: glowIntensity,
                  useOwnLayer: useOwnLayer,
                  quality: quality,
                  settings: settings,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            if (overlayDecoration != null)
              Positioned.fill(
                child: DecoratedBox(decoration: overlayDecoration!),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
