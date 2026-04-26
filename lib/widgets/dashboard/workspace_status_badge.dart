import 'package:flutter/material.dart';

class WorkspaceStatusBadge extends StatelessWidget {
  final String statusText;
  final String tooltip;
  final Color dotColor;
  final bool breathing;
  final Animation<double> breathAnimation;
  final bool inAppBar;
  final VoidCallback? onTap;

  const WorkspaceStatusBadge({
    super.key,
    required this.statusText,
    required this.tooltip,
    required this.dotColor,
    required this.breathing,
    required this.breathAnimation,
    this.inAppBar = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final bg = inAppBar
        ? (isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06))
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final borderColor = inAppBar
        ? (isDark
              ? Colors.white.withValues(alpha: 0.24)
              : Colors.black.withValues(alpha: 0.16))
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.8);
    final textColor = inAppBar
        ? appBarFg.withValues(alpha: 0.94)
        : theme.colorScheme.onSurface;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: inAppBar ? 8 : 10,
            vertical: inAppBar ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WorkspaceDot(
                color: dotColor,
                breathing: breathing,
                size: inAppBar ? 9 : 10,
                animation: breathAnimation,
              ),
              const SizedBox(width: 8),
              Text(
                inAppBar ? 'WS · $statusText' : 'Workspace · $statusText',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceDot extends StatelessWidget {
  final Color color;
  final bool breathing;
  final double size;
  final Animation<double> animation;

  const _WorkspaceDot({
    required this.color,
    required this.breathing,
    required this.size,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (!breathing) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(animation.value);
        final scale = 1.0 + (0.18 * t);
        final glow = 0.15 + (0.35 * t);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.75 + (0.25 * t)),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glow),
                  blurRadius: 10,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
