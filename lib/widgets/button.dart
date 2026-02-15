import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ButtonVariant {
  defaultVariant,
  destructive,
  outline,
  secondary,
  ghost,
  link,
}

enum ButtonSize { defaultSize, sm, lg, icon }

/// Button Widget - A flexible button component with multiple variants
class Button extends StatefulWidget {
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
  final bool enableFeedback; // New: Enable haptic feedback

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
    this.enableFeedback = true,
  }) : assert(
         child != null || text != null,
         'Button must have either child or text',
       );

  @override
  State<Button> createState() => _ButtonState();
}

class _ButtonState extends State<Button> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05, // Scale down by 5%
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.disabled) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.disabled) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.disabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDisabled = widget.disabled || widget.onPressed == null;

    final effectivePadding = _getPadding();
    final effectiveColors = _getColors(colorScheme);
    final effectiveBorderRadius = widget.borderRadius ?? _getBorderRadius();
    final effectiveElevation = widget.elevation ?? _getElevation();
    final effectiveTextStyle =
        widget.textStyle ?? _getTextStyle(theme, effectiveColors.foreground);

    Widget buttonChild;

    if (widget.child != null) {
      buttonChild = widget.child!;
    } else {
      final widgets = <Widget>[];

      if (widget.icon != null) {
        widgets.add(widget.icon!);
      }

      if (widget.icon != null && widget.text != null) {
        widgets.add(SizedBox(width: widget.iconSpacing));
      }

      if (widget.text != null) {
        widgets.add(
          Text(
            widget.text!,
            textAlign: TextAlign.center,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }

      if (widget.text != null && widget.suffixIcon != null) {
        widgets.add(SizedBox(width: widget.iconSpacing));
        widgets.add(widget.suffixIcon!);
      }

      if (widgets.length == 1 && widget.icon != null && widget.text == null) {
        buttonChild = widgets.first;
      } else {
        buttonChild = Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: widget.iconAlignment,
          children: widgets,
        );
      }
    }

    return GestureDetector(
      onTapDown: isDisabled ? null : _handleTapDown,
      onTapUp: isDisabled ? null : _handleTapUp,
      onTapCancel: isDisabled ? null : _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.width,
          height: widget.height ?? _getHeight(),
          child: ElevatedButton(
            onPressed: isDisabled
                ? null
                : () {
                    if (widget.enableFeedback) {
                      HapticFeedback.selectionClick();
                    }
                    widget.onPressed!.call();
                  },
            onLongPress: isDisabled ? null : widget.onLongPress,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                isDisabled
                    ? effectiveColors.disabledBackground
                    : effectiveColors.background,
              ),
              foregroundColor: WidgetStateProperty.all(
                isDisabled
                    ? effectiveColors.disabledForeground
                    : effectiveColors.foreground,
              ),
              overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.pressed)) {
                  return effectiveColors.foreground.withValues(alpha: 0.12);
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
                  side:
                      widget.variant == ButtonVariant.outline ||
                          widget.borderColor != null ||
                          widget.borderWidth != null
                      ? BorderSide(
                          color: isDisabled
                              ? effectiveColors.disabledBorder
                              : effectiveColors.border,
                          width: widget.borderWidth ?? 1.0,
                        )
                      : BorderSide.none,
                ),
              ),
              textStyle: WidgetStateProperty.all(effectiveTextStyle),
              splashFactory: InkRipple.splashFactory,
              visualDensity: VisualDensity.standard,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: buttonChild,
          ),
        ),
      ),
    );
  }

  ButtonColors _getColors(ColorScheme colorScheme) {
    switch (widget.variant) {
      case ButtonVariant.defaultVariant:
        return ButtonColors(
          background: widget.backgroundColor ?? colorScheme.primary,
          foreground: widget.foregroundColor ?? colorScheme.onPrimary,
          border: widget.borderColor ?? Colors.transparent,
          disabledBackground:
              widget.disabledBackgroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForeground:
              widget.disabledForegroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              widget.borderColor ??
              colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.destructive:
        return ButtonColors(
          background: widget.backgroundColor ?? colorScheme.error,
          foreground: widget.foregroundColor ?? colorScheme.onError,
          border: widget.borderColor ?? Colors.transparent,
          disabledBackground:
              widget.disabledBackgroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForeground:
              widget.disabledForegroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              widget.borderColor ??
              colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.outline:
        return ButtonColors(
          background: widget.backgroundColor ?? colorScheme.surface,
          foreground: widget.foregroundColor ?? colorScheme.onSurface,
          border: widget.borderColor ?? colorScheme.outlineVariant,
          disabledBackground:
              widget.disabledBackgroundColor ?? colorScheme.surface,
          disabledForeground:
              widget.disabledForegroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              widget.borderColor ??
              colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.secondary:
        return ButtonColors(
          background: widget.backgroundColor ?? colorScheme.secondary,
          foreground: widget.foregroundColor ?? colorScheme.onSecondary,
          border: widget.borderColor ?? Colors.transparent,
          disabledBackground:
              widget.disabledBackgroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.12),
          disabledForeground:
              widget.disabledForegroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder:
              widget.borderColor ??
              colorScheme.onSurface.withValues(alpha: 0.12),
        );
      case ButtonVariant.ghost:
        return ButtonColors(
          background: widget.backgroundColor ?? Colors.transparent,
          foreground: widget.foregroundColor ?? colorScheme.onSurface,
          border: widget.borderColor ?? Colors.transparent,
          disabledBackground:
              widget.disabledBackgroundColor ?? Colors.transparent,
          disabledForeground:
              widget.disabledForegroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder: widget.borderColor ?? Colors.transparent,
        );
      case ButtonVariant.link:
        return ButtonColors(
          background: widget.backgroundColor ?? Colors.transparent,
          foreground: widget.foregroundColor ?? colorScheme.primary,
          border: widget.borderColor ?? Colors.transparent,
          disabledBackground:
              widget.disabledBackgroundColor ?? Colors.transparent,
          disabledForeground:
              widget.disabledForegroundColor ??
              colorScheme.onSurface.withValues(alpha: 0.38),
          disabledBorder: widget.borderColor ?? Colors.transparent,
        );
    }
  }

  double _getHeight() {
    switch (widget.size) {
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
    switch (widget.size) {
      case ButtonSize.defaultSize:
        return widget.padding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case ButtonSize.sm:
        return widget.padding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.lg:
        return widget.padding ??
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case ButtonSize.icon:
        return widget.padding ?? EdgeInsets.zero;
    }
  }

  double _getBorderRadius() {
    switch (widget.size) {
      case ButtonSize.sm:
        return 10.0;
      case ButtonSize.lg:
        return 14.0;
      case ButtonSize.defaultSize:
      case ButtonSize.icon:
        return 12.0;
    }
  }

  double _getElevation() {
    if (widget.variant == ButtonVariant.outline ||
        widget.variant == ButtonVariant.ghost ||
        widget.variant == ButtonVariant.link) {
      return 0.0;
    }
    switch (widget.size) {
      case ButtonSize.defaultSize:
        return widget.elevation ?? 1.0;
      case ButtonSize.sm:
        return widget.elevation ?? 0.0;
      case ButtonSize.lg:
        return widget.elevation ?? 2.0;
      case ButtonSize.icon:
        return widget.elevation ?? 1.0;
    }
  }

  TextStyle _getTextStyle(ThemeData theme, Color color) {
    final baseStyle =
        theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ) ??
        TextStyle(color: color, fontWeight: FontWeight.w600);

    switch (widget.size) {
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
      child: child,
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
      child: child,
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
      child: child,
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
      child: icon,
    );
  }
}
