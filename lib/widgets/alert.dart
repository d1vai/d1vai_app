import 'package:flutter/material.dart';

enum AlertVariant { defaultVariant, destructive }

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color effectiveBackgroundColor;
    Color effectiveBorderColor;
    IconData defaultIcon;

    switch (variant) {
      case AlertVariant.defaultVariant:
        effectiveBackgroundColor = backgroundColor ??
            colorScheme.surface.withValues(alpha: 0.8);
        effectiveBorderColor = borderColor ??
            colorScheme.outline.withValues(alpha: 0.3);
        defaultIcon = Icons.info_outline;
        break;
      case AlertVariant.destructive:
        effectiveBackgroundColor = backgroundColor ??
            colorScheme.errorContainer.withValues(alpha: 0.3);
        effectiveBorderColor = borderColor ??
            colorScheme.error.withValues(alpha: 0.5);
        defaultIcon = Icons.error_outline;
        break;
    }

    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(8.0);
    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    final effectiveBorderWidth = borderWidth ?? 1.0;

    return Container(
      margin: margin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        border: Border.all(
          color: effectiveBorderColor,
          width: effectiveBorderWidth,
        ),
        borderRadius: effectiveBorderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null || defaultIcon != Icons.info_outline) ...[
            Icon(
              icon != null ? null : defaultIcon,
              color: _getIconColor(theme, variant),
              size: 20,
            ),
            if (icon != null)
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: icon,
              ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: child ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Color _getIconColor(ThemeData theme, AlertVariant variant) {
    switch (variant) {
      case AlertVariant.defaultVariant:
        return theme.colorScheme.primary;
      case AlertVariant.destructive:
        return theme.colorScheme.error;
    }
  }
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
      variant: AlertVariant.destructive, // Using destructive as error
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
