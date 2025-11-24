import 'package:flutter/material.dart';

enum ButtonVariant {
  defaultVariant,
  destructive,
  outline,
  secondary,
  ghost,
  link,
}

enum ButtonSize {
  defaultSize,
  sm,
  lg,
  icon,
}

/// Button Widget - A flexible button component with multiple variants
class Button extends StatelessWidget {
  final Widget? child;
  final String? text;
  final ButtonVariant variant;
  final ButtonSize size;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool disabled;
  final bool shine;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final Widget? icon;
  final Widget? suffixIcon;
  final MainAxisAlignment iconAlignment;
  final double iconSpacing;
  final double? width;
  final double? height;
  final TextStyle? textStyle;

  const Button({
    super.key,
    this.child,
    this.text,
    this.variant = ButtonVariant.defaultVariant,
    this.size = ButtonSize.defaultSize,
    this.onPressed,
    this.onLongPress,
    this.disabled = false,
    this.shine = false,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.elevation,
    this.icon,
    this.suffixIcon,
    this.iconAlignment = MainAxisAlignment.center,
    this.iconSpacing = 8.0,
    this.width,
    this.height,
    this.textStyle,
  }) : assert(
          child != null || text != null,
          'Button must have either child or text',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectivePadding = _getPadding();
    final effectiveColors = _getColors(colorScheme);
    final effectiveBorderRadius = borderRadius ?? 8.0;
    final effectiveElevation = elevation ?? _getElevation();
    final effectiveTextStyle =
        textStyle ?? _getTextStyle(theme, effectiveColors.foreground);

    Widget buttonChild;

    if (child != null) {
      buttonChild = child!;
    } else {
      final widgets = <Widget>[];

      if (icon != null) {
        widgets.add(icon!);
      }

      if (icon != null && text != null) {
        widgets.add(SizedBox(width: iconSpacing));
      }

      if (text != null) {
        widgets.add(Text(text!));
      }

      if (text != null && suffixIcon != null) {
        widgets.add(SizedBox(width: iconSpacing));
        widgets.add(suffixIcon!);
      }

      if (widgets.length == 1 && icon != null && text == null) {
        buttonChild = widgets.first;
      } else {
        buttonChild = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: iconAlignment,
          children: widgets,
        );
      }
    }

    return SizedBox(
      width: width,
      height: height ?? _getHeight(),
      child: ElevatedButton(
        onPressed: disabled ? null : onPressed,
        onLongPress: disabled ? null : onLongPress,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(
            disabled
                ? effectiveColors.disabledBackground
                : effectiveColors.background,
          ),
          foregroundColor: WidgetStateProperty.all(
            disabled
                ? effectiveColors.disabledForeground
                : effectiveColors.foreground,
          ),
          overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.pressed)) {
              return effectiveColors.foreground.withValues(alpha: 0.1);
            } else if (states.contains(WidgetState.hovered)) {
              return effectiveColors.foreground.withValues(alpha: 0.08);
            }
            return Colors.transparent;
          }),
          elevation: WidgetStateProperty.all(effectiveElevation),
          padding: WidgetStateProperty.all(effectivePadding),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              side: borderColor != null || borderWidth != null
                  ? BorderSide(
                      color: disabled
                          ? effectiveColors.disabledBorder
                          : effectiveColors.border,
                      width: borderWidth ?? 1.0,
                    )
                  : BorderSide.none,
            ),
          ),
          textStyle: WidgetStateProperty.all(effectiveTextStyle),
        ),
        child: buttonChild,
      ),
    );
  }

  ButtonColors _getColors(ColorScheme colorScheme) {
    switch (variant) {
      case ButtonVariant.defaultVariant:
        return ButtonColors(
          background:
              backgroundColor ?? colorScheme.primary,
          foreground:
              foregroundColor ?? colorScheme.onPrimary,
          border: borderColor ?? Colors.transparent,
          disabledBackground:
              disabledBackgroundColor ?? colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForeground:
              disabledForegroundColor ?? colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              borderColor ?? colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.destructive:
        return ButtonColors(
          background:
              backgroundColor ?? colorScheme.error,
          foreground:
              foregroundColor ?? colorScheme.onError,
          border: borderColor ?? Colors.transparent,
          disabledBackground:
              disabledBackgroundColor ?? colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForeground:
              disabledForegroundColor ?? colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              borderColor ?? colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.outline:
        return ButtonColors(
          background: backgroundColor ?? colorScheme.surface,
          foreground:
              foregroundColor ?? colorScheme.onSurface,
          border: borderColor ?? colorScheme.outline,
          disabledBackground:
              disabledBackgroundColor ?? colorScheme.surface,
          disabledForeground:
              disabledForegroundColor ?? colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              borderColor ?? colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.secondary:
        return ButtonColors(
          background:
              backgroundColor ?? colorScheme.secondary,
          foreground:
              foregroundColor ?? colorScheme.onSecondary,
          border: borderColor ?? Colors.transparent,
          disabledBackground:
              disabledBackgroundColor ?? colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForeground:
              disabledForegroundColor ?? colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              borderColor ?? colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.ghost:
        return ButtonColors(
          background: backgroundColor ?? Colors.transparent,
          foreground:
              foregroundColor ?? colorScheme.onSurface,
          border: borderColor ?? Colors.transparent,
          disabledBackground: disabledBackgroundColor ?? Colors.transparent,
          disabledForeground:
              disabledForegroundColor ?? colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder: borderColor ?? Colors.transparent,
        );
      case ButtonVariant.link:
        return ButtonColors(
          background: backgroundColor ?? Colors.transparent,
          foreground:
              foregroundColor ?? colorScheme.primary,
          border: borderColor ?? Colors.transparent,
          disabledBackground: disabledBackgroundColor ?? Colors.transparent,
          disabledForeground:
              disabledForegroundColor ?? colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder: borderColor ?? Colors.transparent,
        );
    }
  }

  double _getHeight() {
    switch (size) {
      case ButtonSize.defaultSize:
        return 40.0;
      case ButtonSize.sm:
        return 32.0;
      case ButtonSize.lg:
        return 48.0;
      case ButtonSize.icon:
        return 40.0;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (size) {
      case ButtonSize.defaultSize:
        return padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.sm:
        return padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case ButtonSize.lg:
        return padding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 12);
      case ButtonSize.icon:
        return padding ?? EdgeInsets.zero;
    }
  }

  double _getElevation() {
    if (variant == ButtonVariant.outline ||
        variant == ButtonVariant.ghost ||
        variant == ButtonVariant.link) {
      return 0.0;
    }
    switch (size) {
      case ButtonSize.defaultSize:
        return elevation ?? 2.0;
      case ButtonSize.sm:
        return elevation ?? 1.0;
      case ButtonSize.lg:
        return elevation ?? 4.0;
      case ButtonSize.icon:
        return elevation ?? 2.0;
    }
  }

  TextStyle _getTextStyle(ThemeData theme, Color color) {
    final baseStyle = theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        );

    switch (size) {
      case ButtonSize.defaultSize:
        return baseStyle;
      case ButtonSize.sm:
        return baseStyle.copyWith(fontSize: 12);
      case ButtonSize.lg:
        return baseStyle.copyWith(fontSize: 16);
      case ButtonSize.icon:
        return baseStyle;
    }
  }
}

class ButtonColors {
  final Color background;
  final Color foreground;
  final Color border;
  final Color disabledBackground;
  final Color disabledForeground;
  final Color disabledBorder;

  ButtonColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.disabledBackground,
    required this.disabledForeground,
    required this.disabledBorder,
  });
}

/// OutlinedButton - Wrapper for outline variant
class OutlinedButton extends StatelessWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool disabled;
  final ButtonSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;
  final Widget? suffixIcon;

  const OutlinedButton({
    super.key,
    this.onPressed,
    this.onLongPress,
    this.disabled = false,
    this.size = ButtonSize.defaultSize,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.padding,
    this.icon,
    this.suffixIcon,
    this.child,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      child: child,
      text: text,
      onPressed: onPressed,
      onLongPress: onLongPress,
      disabled: disabled,
      variant: ButtonVariant.outline,
      size: size,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      padding: padding,
      icon: icon,
      suffixIcon: suffixIcon,
    );
  }
}

/// ElevatedButton - Wrapper for default variant
class ElevatedButtonWidget extends StatelessWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool disabled;
  final ButtonSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;
  final Widget? suffixIcon;

  const ElevatedButtonWidget({
    super.key,
    this.onPressed,
    this.onLongPress,
    this.disabled = false,
    this.size = ButtonSize.defaultSize,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.icon,
    this.suffixIcon,
    this.child,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      child: child,
      text: text,
      onPressed: onPressed,
      onLongPress: onLongPress,
      disabled: disabled,
      variant: ButtonVariant.defaultVariant,
      size: size,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      padding: padding,
      icon: icon,
      suffixIcon: suffixIcon,
    );
  }
}

/// TextButton - Wrapper for ghost variant
class TextButtonWidget extends StatelessWidget {
  final Widget? child;
  final String? text;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool disabled;
  final ButtonSize size;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final Widget? icon;
  final Widget? suffixIcon;

  const TextButtonWidget({
    super.key,
    this.onPressed,
    this.onLongPress,
    this.disabled = false,
    this.size = ButtonSize.defaultSize,
    this.foregroundColor,
    this.padding,
    this.icon,
    this.suffixIcon,
    this.child,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      child: child,
      text: text,
      onPressed: onPressed,
      onLongPress: onLongPress,
      disabled: disabled,
      variant: ButtonVariant.ghost,
      size: size,
      foregroundColor: foregroundColor,
      padding: padding,
      icon: icon,
      suffixIcon: suffixIcon,
    );
  }
}

/// IconButton - Specialized button for icon-only buttons
class IconButtonWidget extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool disabled;
  final ButtonVariant variant;
  final double? size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double? borderWidth;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? elevation;

  const IconButtonWidget({
    super.key,
    this.onPressed,
    this.onLongPress,
    this.disabled = false,
    this.variant = ButtonVariant.defaultVariant,
    this.size,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.padding,
    this.elevation,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      child: icon,
      onPressed: onPressed,
      onLongPress: onLongPress,
      disabled: disabled,
      variant: variant,
      size: ButtonSize.icon,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      borderRadius: borderRadius,
      padding: padding,
      elevation: elevation,
      width: size ?? 40.0,
      height: size ?? 40.0,
    );
  }
}
