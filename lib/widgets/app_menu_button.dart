import 'package:flutter/material.dart';

class AppMenuAction<T> {
  final T? value;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool destructive;
  final bool isDivider;

  const AppMenuAction({
    required this.value,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.destructive = false,
    this.isDivider = false,
  });

  const AppMenuAction.divider()
    : value = null,
      label = '',
      icon = Icons.remove,
      enabled = false,
      destructive = false,
      isDivider = true;
}

class AppMenuButton<T> extends StatelessWidget {
  final List<AppMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  final Widget? icon;
  final EdgeInsetsGeometry? padding;
  final bool useFilledBackground;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final PopupMenuPosition position;
  final Offset offset;

  const AppMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    this.tooltip,
    this.icon,
    this.padding,
    this.useFilledBackground = false,
    this.borderRadius = 12,
    this.backgroundColor,
    this.borderColor,
    this.position = PopupMenuPosition.under,
    this.offset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final resolvedBackground =
        backgroundColor ??
        (useFilledBackground
            ? cs.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.34 : 0.76,
              )
            : Colors.transparent);
    final resolvedBorder =
        borderColor ??
        (useFilledBackground
            ? cs.outlineVariant.withValues(alpha: 0.58)
            : Colors.transparent);

    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: position,
      offset: offset,
      padding: EdgeInsets.zero,
      color: Color.alphaBlend(
        cs.surfaceContainerHigh.withValues(alpha: 0.96),
        cs.surface,
      ),
      surfaceTintColor: Colors.transparent,
      shadowColor: cs.shadow.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.68)),
      ),
      onSelected: onSelected,
      itemBuilder: (context) => actions.map<PopupMenuEntry<T>>((action) {
        if (action.isDivider) {
          return const PopupMenuDivider();
        }

        final itemColor = action.destructive ? cs.error : cs.onSurface;
        return PopupMenuItem<T>(
          value: action.value as T,
          enabled: action.enabled,
          child: Row(
            children: [
              Icon(action.icon, size: 18, color: itemColor),
              const SizedBox(width: 10),
              Text(
                action.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: itemColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: padding ?? const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: resolvedBackground,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: resolvedBorder),
        ),
        child:
            icon ??
            Icon(
              Icons.more_vert,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.86),
            ),
      ),
    );
  }
}
