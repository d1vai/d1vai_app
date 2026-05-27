import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app_glass_surface.dart';
import 'app_liquid_glass.dart';

const double _adaptiveModalMobileBreakpoint = 720;

bool useMobileModalLayout(BuildContext context) {
  return MediaQuery.of(context).size.width < _adaptiveModalMobileBreakpoint;
}

Future<T?> showAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool isScrollControlled = true,
  bool useSafeArea = true,
}) {
  if (useMobileModalLayout(context)) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isDismissible: barrierDismissible,
      enableDrag: barrierDismissible,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: builder,
  );
}

class AdaptiveModalContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double desktopMaxHeightFactor;
  final double mobileMaxHeightFactor;
  final bool showMobileHandle;
  final EdgeInsetsGeometry? margin;

  const AdaptiveModalContainer({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.desktopMaxHeightFactor = 0.9,
    this.mobileMaxHeightFactor = 0.94,
    this.showMobileHandle = true,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final mobile = useMobileModalLayout(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = media.viewInsets.bottom;
    final resolvedMargin =
        margin ??
        EdgeInsets.fromLTRB(
          mobile ? 0 : 20,
          mobile ? 0 : 24,
          mobile ? 0 : 20,
          mobile ? 0 : 24,
        );
    final resolvedMarginInsets = resolvedMargin.resolve(
      Directionality.of(context),
    );
    final availableWidth = math.max(
      0.0,
      media.size.width - resolvedMarginInsets.horizontal,
    );
    final constrainedMaxWidth = mobile
        ? availableWidth
        : math.min(maxWidth, availableWidth);
    final constrainedMinWidth = mobile ? availableWidth : 0.0;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(28),
        bottom: Radius.circular(mobile ? 0 : 28),
      ),
    );
    final surfaceBorderRadius = BorderRadius.vertical(
      top: const Radius.circular(28),
      bottom: Radius.circular(mobile ? 0 : 28),
    );
    final shadow = <BoxShadow>[
      BoxShadow(
        color: theme.colorScheme.shadow.withValues(alpha: isDark ? 0.34 : 0.14),
        blurRadius: mobile ? 18 : 30,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: theme.colorScheme.primary.withValues(
          alpha: isDark ? 0.08 : 0.05,
        ),
        blurRadius: mobile ? 20 : 28,
        offset: const Offset(0, 8),
      ),
    ];
    final glassSettings = LiquidGlassSettings(
      blur: isDark ? 18 : 12,
      thickness: isDark ? 30 : 24,
      glassColor: Color.lerp(
        theme.colorScheme.surface.withValues(alpha: isDark ? 0.24 : 0.30),
        theme.colorScheme.primary.withValues(alpha: isDark ? 0.10 : 0.05),
        0.24,
      )!,
      lightIntensity: isDark ? 0.24 : 0.34,
      saturation: isDark ? 1.18 : 1.08,
      glowIntensity: isDark ? 0.32 : 0.16,
      standardOpacityMultiplier: isDark ? 1.0 : 0.72,
    );

    final surface = AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: mobile ? Alignment.bottomCenter : Alignment.center,
        child: Container(
          margin: resolvedMargin,
          constraints: BoxConstraints(
            maxWidth: constrainedMaxWidth,
            maxHeight:
                media.size.height *
                (mobile ? mobileMaxHeightFactor : desktopMaxHeightFactor),
            minWidth: constrainedMinWidth,
          ),
          child: Material(
            color: Colors.transparent,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: AppGlassSurface(
              variant: AppLiquidGlassVariant.floating,
              borderRadius: surfaceBorderRadius,
              glassBorderRadius: 28,
              glowIntensity: isDark ? 0.14 : 0.08,
              useOwnLayer: !mobile,
              quality: GlassQuality.premium,
              settings: glassSettings,
              boxShadow: shadow,
              overlayDecoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: isDark ? 0.52 : 0.72,
                  ),
                ),
                borderRadius: surfaceBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: isDark ? 0.06 : 0.22),
                    Color.alphaBlend(
                      theme.colorScheme.primary.withValues(
                        alpha: isDark ? 0.08 : 0.04,
                      ),
                      theme.colorScheme.surface,
                    ).withValues(alpha: isDark ? 0.92 : 0.96),
                    theme.colorScheme.surface.withValues(
                      alpha: isDark ? 0.92 : 0.98,
                    ),
                  ],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (mobile && showMobileHandle)
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 6),
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    Flexible(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final translateY = mobile ? (1 - value) * 18 : (1 - value) * 8;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              scale: mobile ? 1.0 : (0.985 + (0.015 * value)),
              child: child,
            ),
          ),
        );
      },
      child: surface,
    );
  }
}

class AdaptiveModalHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AdaptiveModalHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    return Padding(
      padding: padding,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 40,
                child: leading == null ? null : Center(child: leading!),
              ),
              const Spacer(),
              SizedBox(
                width: 40,
                child: trailing != null
                    ? Center(child: trailing!)
                    : onClose != null
                    ? Center(
                        child: IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
