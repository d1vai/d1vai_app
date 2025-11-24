import 'package:flutter/material.dart';

enum BadgeVariant {
  defaultVariant,
  secondary,
  destructive,
  outline,
}

class Badge extends StatelessWidget {
  final Widget? child;
  final String? label;
  final BadgeVariant variant;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final BorderRadius? borderRadiusGeometry;
  final double? fontSize;
  final FontWeight? fontWeight;
  final VoidCallback? onTap;
  final bool deletable;
  final VoidCallback? onDelete;
  final IconData? deleteIcon;
  final double? deleteIconSize;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Duration? animationDuration;
  final bool animated;

  const Badge({
    super.key,
    this.child,
    this.label,
    this.variant = BadgeVariant.defaultVariant,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.padding,
    this.margin,
    this.borderRadius,
    this.borderRadiusGeometry,
    this.fontSize,
    this.fontWeight,
    this.onTap,
    this.deletable = false,
    this.onDelete,
    this.deleteIcon,
    this.deleteIconSize,
    this.border,
    this.boxShadow,
    this.animationDuration,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Base styling based on variant
    final variantStyle = _getVariantStyle(colorScheme);

    // Custom overrides
    final bgColor = backgroundColor ?? variantStyle['bgColor'] as Color;
    final txtColor = textColor ?? variantStyle['textColor'] as Color;
    final brdColor = borderColor ?? variantStyle['borderColor'];

    final effectivePadding = padding ??
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    Widget badgeContent = Container(
      margin: margin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: variant == BadgeVariant.outline ? null : bgColor,
        border: border ??
            Border.all(
              color: brdColor ?? Colors.transparent,
              width: 1,
            ),
        borderRadius: borderRadiusGeometry ??
            BorderRadius.circular(borderRadius ?? 6),
        boxShadow: boxShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (child != null)
            child!
          else if (label != null)
            Text(
              label!,
              style: TextStyle(
                fontSize: fontSize ?? 12,
                fontWeight: fontWeight ?? FontWeight.w600,
                color: txtColor,
              ),
            ),
          if (deletable && onDelete != null) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  deleteIcon ?? Icons.close,
                  size: deleteIconSize ?? 14,
                  color: txtColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (animated && (onTap != null || deletable)) {
      return AnimatedContainer(
        duration: animationDuration ?? const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              borderRadiusGeometry ?? BorderRadius.circular(borderRadius ?? 6),
          child: badgeContent,
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius:
          borderRadiusGeometry ?? BorderRadius.circular(borderRadius ?? 6),
      child: badgeContent,
    );
  }

  Map<String, Color> _getVariantStyle(ColorScheme colorScheme) {
    switch (variant) {
      case BadgeVariant.defaultVariant:
        return {
          'bgColor': colorScheme.primary,
          'textColor': colorScheme.onPrimary,
          'borderColor': colorScheme.primary.withValues(alpha: 0.8),
        };
      case BadgeVariant.secondary:
        return {
          'bgColor': colorScheme.secondary,
          'textColor': colorScheme.onSecondary,
          'borderColor': colorScheme.secondary.withValues(alpha: 0.8),
        };
      case BadgeVariant.destructive:
        return {
          'bgColor': colorScheme.error,
          'textColor': colorScheme.onError,
          'borderColor': colorScheme.error.withValues(alpha: 0.8),
        };
      case BadgeVariant.outline:
        return {
          'bgColor': Colors.transparent,
          'textColor': colorScheme.onSurface,
          'borderColor': colorScheme.outline,
        };
    }
  }
}

/// Status Badge - pre-configured badge for common statuses
class StatusBadge extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;
  final bool deletable;
  final VoidCallback? onDelete;

  const StatusBadge({
    super.key,
    required this.status,
    this.onTap,
    this.deletable = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase();

    BadgeVariant variant;
    Color color;

    switch (normalizedStatus) {
      case 'active':
      case 'success':
      case 'completed':
      case 'verified':
        variant = BadgeVariant.defaultVariant;
        color = Colors.green;
        break;
      case 'pending':
      case 'processing':
      case 'waiting':
        variant = BadgeVariant.secondary;
        color = Colors.amber;
        break;
      case 'error':
      case 'failed':
      case 'cancelled':
      case 'rejected':
        variant = BadgeVariant.destructive;
        color = Colors.red;
        break;
      case 'new':
      case 'draft':
      case 'inactive':
        variant = BadgeVariant.outline;
        color = Colors.grey;
        break;
      default:
        variant = BadgeVariant.secondary;
        color = Colors.blue;
    }

    return Badge(
      label: status,
      variant: variant,
      onTap: onTap,
      deletable: deletable,
      onDelete: onDelete,
      backgroundColor: color.withValues(alpha: 0.1),
      textColor: color,
      borderColor: color.withValues(alpha: 0.3),
    );
  }
}

/// Feature Badge - for highlighting features or tags
class FeatureBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final bool deletable;
  final VoidCallback? onDelete;

  const FeatureBadge({
    super.key,
    required this.label,
    this.color,
    this.onTap,
    this.deletable = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? Theme.of(context).colorScheme.primary;

    return Badge(
      label: label,
      variant: BadgeVariant.outline,
      onTap: onTap,
      deletable: deletable,
      onDelete: onDelete,
      backgroundColor: badgeColor.withValues(alpha: 0.1),
      textColor: badgeColor,
      borderColor: badgeColor.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      borderRadius: 4,
    );
  }
}

/// Count Badge - for showing counts or numbers
class CountBadge extends StatelessWidget {
  final int count;
  final Color? color;
  final VoidCallback? onTap;

  const CountBadge({
    super.key,
    required this.count,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? Theme.of(context).colorScheme.error;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Premium Badge - for highlighting premium features
class PremiumBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const PremiumBadge({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final goldColor = Colors.amber.shade400;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              goldColor,
              Colors.amber.shade600,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: goldColor.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              size: 12,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              'Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
