import 'package:flutter/material.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  final Widget? icon;
  final bool isCurrentPage;
  final bool enabled;

  BreadcrumbItem({
    required this.label,
    this.onTap,
    this.icon,
    this.isCurrentPage = false,
    this.enabled = true,
  });
}

class Breadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final Widget? separator;
  final EdgeInsetsGeometry? padding;
  final Color? separatorColor;
  final double? separatorSpacing;
  final TextStyle? textStyle;
  final TextStyle? currentPageStyle;
  final bool showIcons;
  final int? maxItems;
  final Widget? ellipsis;

  const Breadcrumb({
    super.key,
    required this.items,
    this.separator,
    this.padding,
    this.separatorColor,
    this.separatorSpacing,
    this.textStyle,
    this.currentPageStyle,
    this.showIcons = false,
    this.maxItems,
    this.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveTextStyle =
        textStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(color: colorScheme.onSurfaceVariant);
    final effectiveCurrentStyle =
        currentPageStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ) ??
        TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w800);

    List<BreadcrumbItem> displayItems = items;
    Widget? ellipsisWidget = ellipsis;

    if (maxItems != null && items.length > maxItems!) {
      final firstItem = items.first;
      final lastItems = items.skip(items.length - (maxItems! - 2)).toList();
      displayItems = [firstItem, ...lastItems];
      ellipsisWidget ??= _DefaultEllipsis(
        color: separatorColor ?? colorScheme.onSurfaceVariant,
      );
    }

    final effectiveSeparator =
        separator ??
        Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color:
              separatorColor ??
              colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        );

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Wrap(
        spacing: separatorSpacing ?? 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _buildBreadcrumbItems(
          context,
          displayItems,
          effectiveSeparator,
          effectiveTextStyle,
          effectiveCurrentStyle,
          ellipsisWidget,
        ),
      ),
    );
  }

  List<Widget> _buildBreadcrumbItems(
    BuildContext context,
    List<BreadcrumbItem> items,
    Widget separator,
    TextStyle textStyle,
    TextStyle currentPageStyle,
    Widget? ellipsisWidget,
  ) {
    final widgets = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (i == 1 && ellipsisWidget != null && maxItems != null) {
        widgets.add(ellipsisWidget);
      }

      final isLast = i == items.length - 1;
      widgets.add(
        _BreadcrumbNode(
          item: item,
          textStyle: item.isCurrentPage ? currentPageStyle : textStyle,
          showIcon: showIcons,
          isLast: isLast,
        ),
      );

      if (!isLast) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: separatorSpacing ?? 2),
            child: separator,
          ),
        );
      }
    }

    return widgets;
  }
}

class _BreadcrumbNode extends StatelessWidget {
  const _BreadcrumbNode({
    required this.item,
    required this.textStyle,
    required this.showIcon,
    required this.isLast,
  });

  final BreadcrumbItem item;
  final TextStyle textStyle;
  final bool showIcon;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInteractive =
        !item.isCurrentPage && item.enabled && item.onTap != null && !isLast;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: item.isCurrentPage
            ? colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: item.isCurrentPage
            ? Border.all(color: colorScheme.primary.withValues(alpha: 0.18))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.icon != null && showIcon) ...[
            IconTheme(
              data: IconThemeData(
                size: 14,
                color: item.isCurrentPage
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              child: item.icon!,
            ),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              item.label,
              style: textStyle.copyWith(
                color: item.isCurrentPage
                    ? colorScheme.primary
                    : textStyle.color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (!isInteractive) {
      return Opacity(opacity: item.enabled ? 1.0 : 0.5, child: chip);
    }

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: chip,
    );
  }
}

class _DefaultEllipsis extends StatelessWidget {
  const _DefaultEllipsis({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '...',
        style:
            Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ) ??
            TextStyle(color: color),
      ),
    );
  }
}

class SimpleBreadcrumb extends StatelessWidget {
  final List<String> labels;
  final int? currentIndex;
  final Function(int)? onItemTap;
  final Widget? separator;
  final Color? separatorColor;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final TextStyle? currentPageStyle;
  final Widget? leading;
  final Widget? trailing;

  const SimpleBreadcrumb({
    super.key,
    required this.labels,
    this.currentIndex,
    this.onItemTap,
    this.separator,
    this.separatorColor,
    this.padding,
    this.textStyle,
    this.currentPageStyle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final breadcrumbItems = <BreadcrumbItem>[];

    if (leading != null) {
      breadcrumbItems.add(BreadcrumbItem(label: '', isCurrentPage: false));
    }

    for (int i = 0; i < labels.length; i++) {
      final isCurrent = i == (currentIndex ?? labels.length - 1);
      breadcrumbItems.add(
        BreadcrumbItem(
          label: labels[i],
          isCurrentPage: isCurrent,
          onTap: isCurrent || onItemTap == null ? null : () => onItemTap!(i),
        ),
      );
    }

    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Expanded(
          child: Breadcrumb(
            items: breadcrumbItems,
            separator: separator,
            separatorColor: separatorColor,
            padding: padding,
            textStyle: textStyle,
            currentPageStyle: currentPageStyle,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class CustomBreadcrumb extends StatelessWidget {
  final List<Widget> items;
  final Widget? separator;
  final EdgeInsetsGeometry? padding;
  final Color? separatorColor;
  final double? separatorSpacing;

  const CustomBreadcrumb({
    super.key,
    required this.items,
    this.separator,
    this.padding,
    this.separatorColor,
    this.separatorSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveSeparator =
        separator ??
        Icon(
          Icons.chevron_right_rounded,
          size: 16,
          color:
              separatorColor ??
              colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        );

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: separatorSpacing ?? 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items.asMap().entries.expand((entry) {
          final index = entry.key;
          final widget = entry.value;
          if (index < items.length - 1) {
            return [widget, effectiveSeparator];
          }
          return [widget];
        }).toList(),
      ),
    );
  }
}
