import 'package:flutter/material.dart';

import '../utils/navigation_utils.dart';
import 'app_glass_surface.dart';
import 'app_liquid_glass.dart';

class WebSubPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WebSubPageAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.centerTitle,
    this.onClose,
    this.fallbackRoute,
    this.closeTooltip = 'Close',
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final VoidCallback? onClose;
  final String? fallbackRoute;
  final String closeTooltip;

  static const double _toolbarHeight = 56;
  static const double _statusBarAllowance = 12;

  @override
  Size get preferredSize => Size.fromHeight(
    _toolbarHeight + _statusBarAllowance + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final resolvedActions = actions ?? const <Widget>[];

    return Material(
      color: Colors.transparent,
      child: AppGlassSurface(
        variant: AppLiquidGlassVariant.navigation,
        borderRadius: BorderRadius.zero,
        glassBorderRadius: 0,
        glowIntensity: isDark ? 0.12 : 0.06,
        useOwnLayer: isDark,
        overlayDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A).withValues(alpha: 0.20),
                    const Color(0xFF111B31).withValues(alpha: 0.14),
                    colorScheme.primary.withValues(alpha: 0.08),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.64),
                    colorScheme.surface.withValues(alpha: 0.56),
                    colorScheme.surfaceContainerLowest.withValues(alpha: 0.30),
                  ],
          ),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colorScheme.outlineVariant.withValues(alpha: 0.75),
            ),
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _toolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Row(
                    children: [
                      _AppBarGlassIconButton(
                        tooltip: closeTooltip,
                        icon: Icons.close_rounded,
                        onPressed:
                            onClose ??
                            () => NavigationUtils.popOrGo(
                              context,
                              fallbackRoute ?? '/',
                            ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DefaultTextStyle(
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(),
                          child: Align(
                            alignment: centerTitle == true
                                ? Alignment.center
                                : Alignment.centerLeft,
                            child: title,
                          ),
                        ),
                      ),
                      if (resolvedActions.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: resolvedActions
                              .map(
                                (action) => Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _wrapAction(action),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapAction(Widget action) {
    if (action is IconButton) {
      return _AppBarGlassIconButton(
        tooltip: action.tooltip ?? '',
        iconWidget: action.icon,
        onPressed: action.onPressed,
      );
    }
    return action;
  }
}

class _AppBarGlassIconButton extends StatelessWidget {
  const _AppBarGlassIconButton({
    required this.tooltip,
    this.icon,
    this.iconWidget,
    required this.onPressed,
  });

  final String tooltip;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AppGlassSurface(
      variant: AppLiquidGlassVariant.floating,
      borderRadius: BorderRadius.circular(14),
      glassBorderRadius: 14,
      glowIntensity: isDark ? 0.10 : 0.04,
      overlayDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.04 : 0.72),
            colorScheme.surface.withValues(alpha: isDark ? 0.04 : 0.34),
          ],
        ),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          icon:
              iconWidget ??
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
