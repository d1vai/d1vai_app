import 'package:flutter/material.dart';

enum AlertVariant { defaultVariant, destructive, success, warning }

/// Alert Widget - Display important messages to users with different variants
class Alert extends StatelessWidget {
  final AlertVariant variant;
  final Widget? icon;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final bool showDefaultIcon;

  const Alert({
    super.key,
    this.variant = AlertVariant.defaultVariant,
    this.icon,
    this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.showDefaultIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final resolved = _resolveStyle(colorScheme, variant);

    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(12.0);
    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    final effectiveBorderWidth = borderWidth ?? 1.0;

    final Widget? leading = icon ??
        (showDefaultIcon && resolved.defaultIcon != null
            ? Icon(
                resolved.defaultIcon,
                color: resolved.iconColor,
                size: 18,
              )
            : null);

    return Container(
      margin: margin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: backgroundColor ?? resolved.backgroundColor,
        border: Border.all(
          color: borderColor ?? resolved.borderColor,
          width: effectiveBorderWidth,
        ),
        borderRadius: effectiveBorderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: IconTheme.merge(
                data: IconThemeData(color: resolved.iconColor, size: 18),
                child: leading,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: child ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  _AlertResolvedStyle _resolveStyle(
    ColorScheme colorScheme,
    AlertVariant variant,
  ) {
    switch (variant) {
      case AlertVariant.defaultVariant:
        return _AlertResolvedStyle(
          backgroundColor: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.surface,
          ),
          borderColor: Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.outlineVariant,
          ),
          iconColor: colorScheme.primary,
          defaultIcon: null,
        );
      case AlertVariant.destructive:
        return _AlertResolvedStyle(
          backgroundColor: Color.alphaBlend(
            colorScheme.error.withValues(alpha: 0.10),
            colorScheme.surface,
          ),
          borderColor: Color.alphaBlend(
            colorScheme.error.withValues(alpha: 0.30),
            colorScheme.outlineVariant,
          ),
          iconColor: colorScheme.error,
          defaultIcon: Icons.error_outline,
        );
      case AlertVariant.success:
        return _AlertResolvedStyle(
          backgroundColor: Color.alphaBlend(
            colorScheme.tertiary.withValues(alpha: 0.10),
            colorScheme.surface,
          ),
          borderColor: Color.alphaBlend(
            colorScheme.tertiary.withValues(alpha: 0.30),
            colorScheme.outlineVariant,
          ),
          iconColor: colorScheme.tertiary,
          defaultIcon: Icons.check_circle_outline,
        );
      case AlertVariant.warning:
        return _AlertResolvedStyle(
          backgroundColor: Color.alphaBlend(
            colorScheme.secondary.withValues(alpha: 0.10),
            colorScheme.surface,
          ),
          borderColor: Color.alphaBlend(
            colorScheme.secondary.withValues(alpha: 0.30),
            colorScheme.outlineVariant,
          ),
          iconColor: colorScheme.secondary,
          defaultIcon: Icons.warning_amber_rounded,
        );
    }
  }
}

class _AlertResolvedStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final IconData? defaultIcon;

  const _AlertResolvedStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.defaultIcon,
  });
}

/// AlertDescription - Description content for Alert
class AlertDescription extends StatelessWidget {
  final Widget? child;
  final String? text;
  final TextStyle? style;
  final EdgeInsetsGeometry? padding;

  const AlertDescription({
    super.key,
    this.child,
    this.text,
    this.style,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ??
        theme.textTheme.bodyMedium?.copyWith(
          height: 1.5,
        ) ??
        const TextStyle(
          fontSize: 14,
          height: 1.5,
        );

    final content = child ??
        (text != null
            ? Text(
                text!,
                style: effectiveStyle,
              )
            : const SizedBox.shrink());

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: content,
    );
  }
}

/// Simple Alert Builder - Helper to create common alerts
class SimpleAlert extends StatelessWidget {
  final String message;
  final String? title;
  final AlertVariant variant;

  const SimpleAlert({
    super.key,
    required this.message,
    this.title,
    this.variant = AlertVariant.defaultVariant,
  });

  @override
  Widget build(BuildContext context) {
    return Alert(
      variant: variant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          AlertDescription(text: message),
        ],
      ),
    );
  }
}

/// Success Alert - For success messages
class SuccessAlert extends StatelessWidget {
  final String message;
  final String? title;

  const SuccessAlert({
    super.key,
    required this.message,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleAlert(
      message: message,
      title: title,
      variant: AlertVariant.success,
    );
  }
}

/// Error Alert - For error messages
class ErrorAlert extends StatelessWidget {
  final String message;
  final String? title;

  const ErrorAlert({
    super.key,
    required this.message,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleAlert(
      message: message,
      title: title ?? 'Error',
      variant: AlertVariant.destructive,
    );
  }
}

/// Info Alert - For info messages
class InfoAlert extends StatelessWidget {
  final String message;
  final String? title;

  const InfoAlert({
    super.key,
    required this.message,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleAlert(
      message: message,
      title: title,
      variant: AlertVariant.defaultVariant,
    );
  }
}

/// Warning Alert - For warning messages
class WarningAlert extends StatelessWidget {
  final String message;
  final String? title;

  const WarningAlert({
    super.key,
    required this.message,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleAlert(
      message: message,
      title: title ?? 'Warning',
      variant: AlertVariant.warning,
    );
  }
}
