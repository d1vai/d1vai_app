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
    final effectiveTextStyle = textStyle ??
        TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        );
    final effectiveCurrentStyle = currentPageStyle ??
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        );

    List<BreadcrumbItem> displayItems = items;
    Widget? ellipsisWidget = ellipsis;

    // Handle max items truncation
    if (maxItems != null && items.length > maxItems!) {
      final firstItem = items.first;
      final lastItems = items.skip(items.length - (maxItems! - 2)).toList();
      displayItems = [firstItem, ...lastItems];

      ellipsisWidget ??= _DefaultEllipsis(
        color: separatorColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.5),
      );
    }

    final effectiveSeparator = separator ??
        Icon(
          Icons.chevron_right,
          size: 16,
          color: separatorColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.5),
        );

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: separatorSpacing ?? 8,
        runSpacing: 4,
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
    final List<Widget> widgets = [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      // Add ellipsis before truncated items
      if (i == 1 && ellipsisWidget != null && maxItems != null) {
        widgets.add(ellipsisWidget);
      }

      final isLast = i == items.length - 1;

      Widget itemWidget = _BreadcrumbItem(
        item: item,
        textStyle: item.isCurrentPage ? currentPageStyle : textStyle,
        showIcon: showIcons,
        isLast: isLast,
      );

      widgets.add(itemWidget);

      // Add separator between items (except after last)
      if (!isLast) {
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(horizontal: separatorSpacing ?? 4),
          child: separator,
        ));
      }
    }

    return widgets;
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final BreadcrumbItem item;
  final TextStyle? textStyle;
  final bool showIcon;
  final bool isLast;

  const _BreadcrumbItem({
    required this.item,
    required this.textStyle,
    required this.showIcon,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.icon != null && showIcon) ...[
          item.icon!,
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            item.label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (item.isCurrentPage || !item.enabled || item.onTap == null || isLast) {
      return Opacity(
        opacity: item.enabled ? 1.0 : 0.5,
        child: content,
      );
    }

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: content,
      ),
    );
  }
}

class _DefaultEllipsis extends StatelessWidget {
  final Color color;

  const _DefaultEllipsis({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(
        '...',
        style: TextStyle(
          color: color,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// Simple Breadcrumb with automatic handling
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
    final theme = Theme.of(context);
    final breadcrumbItems = <BreadcrumbItem>[];

    // Add leading widget if provided
    if (leading != null) {
      breadcrumbItems.add(
        BreadcrumbItem(label: '', isCurrentPage: false, onTap: null),
      );
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

    final effectiveStyle = textStyle ??
        TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        );
    final effectiveCurrentStyle = currentPageStyle ??
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        );

    final effectiveSeparator = separator ??
        Icon(
          Icons.chevron_right,
          size: 16,
          color: separatorColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.5),
        );

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: _buildItems(breadcrumbItems, effectiveStyle, effectiveCurrentStyle, effectiveSeparator),
      ),
    );
  }

  List<Widget> _buildItems(
    List<BreadcrumbItem> items,
    TextStyle textStyle,
    TextStyle currentPageStyle,
    Widget separator,
  ) {
    final List<Widget> widgets = [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];

      final style = item.isCurrentPage ? currentPageStyle : textStyle;

      widgets.add(
        InkWell(
          onTap: item.isCurrentPage || item.onTap == null ? null : item.onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              item.label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );

      if (i < items.length - 1) {
        widgets.add(separator);
      }
    }

    return widgets;
  }
}

/// Breadcrumb with custom widgets for each item
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

    final effectiveSeparator = separator ??
        Icon(
          Icons.chevron_right,
          size: 16,
          color: separatorColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.5),
        );

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: separatorSpacing ?? 8,
        runSpacing: 4,
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
