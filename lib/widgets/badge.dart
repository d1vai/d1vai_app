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
    final isDark = theme.brightness == Brightness.dark;

    // Base styling based on variant
    final variantStyle = _getVariantStyle(colorScheme);

    // Custom overrides
    final bgColor = backgroundColor ?? variantStyle['bgColor'] as Color;
    final txtColor = textColor ?? variantStyle['textColor'] as Color;
    final brdColor = borderColor ?? variantStyle['borderColor'];

    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    final effectiveRadius =
        borderRadiusGeometry ??
        BorderRadius.circular(borderRadius ?? 999);

    final content = child ??
        (label != null
            ? Text(
                label!,
                style: TextStyle(
                  fontSize: fontSize ?? 11,
                  fontWeight: fontWeight ?? FontWeight.w800,
                  color: txtColor,
                  letterSpacing: 0.2,
                ),
              )
            : const SizedBox.shrink());

    final badgeBody = AnimatedContainer(
      duration: animated
          ? (animationDuration ?? const Duration(milliseconds: 180))
          : Duration.zero,
      curve: Curves.easeOut,
      margin: margin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: variant == BadgeVariant.outline ? null : bgColor,
        border: border ??
            Border.all(
              color: brdColor ?? Colors.transparent,
              width: 1,
            ),
        borderRadius: effectiveRadius,
        boxShadow:
            boxShadow ??
            (variant == BadgeVariant.outline
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ]),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: content),
          if (deletable && onDelete != null) ...[
            const SizedBox(width: 4),
            SizedBox(
              width: 22,
              height: 22,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(999),
                  child: Center(
                    child: Icon(
                      deleteIcon ?? Icons.close_rounded,
                      size: deleteIconSize ?? 14,
                      color: txtColor.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null && !(deletable && onDelete != null)) return badgeBody;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        child: badgeBody,
      ),
    );
  }

  Map<String, Color> _getVariantStyle(ColorScheme colorScheme) {
    switch (variant) {
      case BadgeVariant.defaultVariant:
        return {
          'bgColor': Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.surface,
          ),
          'textColor': colorScheme.primary,
          'borderColor': Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.outlineVariant,
          ),
        };
      case BadgeVariant.secondary:
        return {
          'bgColor': Color.alphaBlend(
            colorScheme.secondary.withValues(alpha: 0.12),
            colorScheme.surface,
          ),
          'textColor': colorScheme.secondary,
          'borderColor': Color.alphaBlend(
            colorScheme.secondary.withValues(alpha: 0.22),
            colorScheme.outlineVariant,
          ),
        };
      case BadgeVariant.destructive:
        return {
          'bgColor': Color.alphaBlend(
            colorScheme.error.withValues(alpha: 0.12),
            colorScheme.surface,
          ),
          'textColor': colorScheme.error,
          'borderColor': Color.alphaBlend(
            colorScheme.error.withValues(alpha: 0.22),
            colorScheme.outlineVariant,
          ),
        };
      case BadgeVariant.outline:
        return {
          'bgColor': Colors.transparent,
          'textColor': colorScheme.onSurfaceVariant,
          'borderColor': colorScheme.outlineVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedStatus = status.toLowerCase();

    BadgeVariant variant;
    Color color;

    switch (normalizedStatus) {
      case 'active':
      case 'success':
      case 'completed':
      case 'verified':
        variant = BadgeVariant.defaultVariant;
        color = colorScheme.tertiary;
        break;
      case 'pending':
      case 'processing':
      case 'waiting':
        variant = BadgeVariant.secondary;
        color = colorScheme.secondary;
        break;
      case 'error':
      case 'failed':
      case 'cancelled':
      case 'rejected':
        variant = BadgeVariant.destructive;
        color = colorScheme.error;
        break;
      case 'new':
      case 'draft':
      case 'inactive':
        variant = BadgeVariant.outline;
        color = colorScheme.onSurfaceVariant;
        break;
      default:
        variant = BadgeVariant.secondary;
        color = colorScheme.primary;
    }

    return Badge(
      label: status,
      variant: variant,
      onTap: onTap,
      deletable: deletable,
      onDelete: onDelete,
      backgroundColor: Color.alphaBlend(
        color.withValues(alpha: 0.12),
        colorScheme.surface,
      ),
      textColor: color,
      borderColor: Color.alphaBlend(
        color.withValues(alpha: 0.22),
        colorScheme.outlineVariant,
      ),
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
