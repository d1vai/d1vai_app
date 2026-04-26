import 'package:flutter/material.dart';

class WebSubPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WebSubPageAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.centerTitle,
    this.onClose,
    this.closeTooltip = 'Close',
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool? centerTitle;
  final VoidCallback? onClose;
  final String closeTooltip;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final resolvedActions = actions ?? const <Widget>[];

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF111B31),
                    colorScheme.primary.withValues(alpha: 0.08),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF8FAFC),
                    const Color(0xFFFDF4FF),
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
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: kToolbarHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      _AppBarGlassIconButton(
                        tooltip: closeTooltip,
                        icon: Icons.close_rounded,
                        onPressed:
                            onClose ?? () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DefaultTextStyle(
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
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
              if (bottom != null) bottom!,
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

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon:
            iconWidget ??
            Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        onPressed: onPressed,
      ),
    );
  }
}
