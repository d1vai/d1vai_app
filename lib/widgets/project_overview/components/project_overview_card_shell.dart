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

    final surface =
        backgroundColor ??
        Color.alphaBlend(
          colorScheme.primary.withValues(alpha: isDark ? 0.045 : 0.016),
          colorScheme.surface,
        );

    final outline =
        borderColor ??
        colorScheme.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.30);

    return CustomCard(
      margin: margin,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      borderRadius: 14,
      backgroundColor: surface,
      borderColor: outline,
      child: Stack(
        children: [
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 1.5,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      accent.withValues(alpha: isDark ? 0.38 : 0.06),
                      colorScheme.secondary.withValues(
                        alpha: isDark ? 0.14 : 0.03,
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
