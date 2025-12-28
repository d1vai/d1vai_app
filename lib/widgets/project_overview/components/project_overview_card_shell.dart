import 'package:flutter/material.dart';

import '../../../widgets/card.dart';

class ProjectOverviewCardShell extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ProjectOverviewCardShell({
    super.key,
    required this.child,
    this.accentColor,
    this.borderColor,
    this.backgroundColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final accent = accentColor ?? colorScheme.primary;

    final surface = backgroundColor ??
        Color.alphaBlend(
          colorScheme.primary.withValues(alpha: isDark ? 0.055 : 0.022),
          colorScheme.surface,
        );

    final outline =
        borderColor ??
        colorScheme.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.30);

    return CustomCard(
      margin: margin,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      borderRadius: 16,
      backgroundColor: surface,
      borderColor: outline,
      child: Stack(
        children: [
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      accent.withValues(alpha: isDark ? 0.55 : 0.08),
                      colorScheme.secondary.withValues(
                        alpha: isDark ? 0.22 : 0.04,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
