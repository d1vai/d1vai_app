import 'package:flutter/material.dart';

class Checkbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? activeBorderColor;
  final Color? inactiveBorderColor;
  final Color? checkColor;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final String? label;
  final TextStyle? labelStyle;
  final MainAxisAlignment labelAlignment;
  final bool showLabel;
  final Duration duration;
  final bool tristate;

  const Checkbox({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.size = 18.0,
    this.activeColor,
    this.inactiveColor,
    this.activeBorderColor,
    this.inactiveBorderColor,
    this.checkColor,
    this.borderWidth = 2.0,
    this.borderRadius,
    this.label,
    this.labelStyle,
    this.labelAlignment = MainAxisAlignment.start,
    this.showLabel = true,
    this.duration = const Duration(milliseconds: 200),
    this.tristate = false,
  });

  @override
  State<Checkbox> createState() => _CheckboxState();
}

class _CheckboxState extends State<Checkbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late bool _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;

    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    if (_currentValue) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(Checkbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _currentValue = widget.value;
      if (_currentValue) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) return;

    if (widget.tristate) {
      // Cycle through null -> true -> false -> null
      if (_currentValue == false) {
        _currentValue = true;
      } else if (_currentValue == true) {
        _currentValue = false;
      } else {
        _currentValue = true;
      }
    } else {
      _currentValue = !_currentValue;
    }

    if (_currentValue) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    widget.onChanged?.call(_currentValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveActiveColor = widget.activeColor ??
        colorScheme.primary;
    final effectiveInactiveColor = widget.inactiveColor ??
        colorScheme.surface;
    final effectiveActiveBorderColor = widget.activeBorderColor ??
        effectiveActiveColor;
    final effectiveInactiveBorderColor = widget.inactiveBorderColor ??
        colorScheme.outline;
    final effectiveCheckColor = widget.checkColor ?? Colors.white;

    final effectiveBorderRadius = widget.borderRadius ??
        BorderRadius.circular(3.0);

    Widget checkboxWidget = GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _currentValue ? effectiveActiveColor : effectiveInactiveColor,
          border: Border.all(
            color: _currentValue
                ? effectiveActiveBorderColor
                : effectiveInactiveBorderColor,
            width: widget.borderWidth,
          ),
          borderRadius: effectiveBorderRadius,
        ),
        child: _currentValue
            ? ScaleTransition(
                scale: _scaleAnimation,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Icon(
                    Icons.check,
                    size: widget.size * 0.7,
                    color: effectiveCheckColor,
                  ),
                ),
              )
            : null,
      ),
    );

    if (widget.showLabel && widget.label != null) {
      final labelWidget = Text(
        widget.label!,
        style: widget.labelStyle ??
            theme.textTheme.bodyMedium,
      );

      if (widget.labelAlignment == MainAxisAlignment.start) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            checkboxWidget,
            const SizedBox(width: 8),
            labelWidget,
          ],
        );
      } else {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            checkboxWidget,
            const SizedBox(height: 4),
            labelWidget,
          ],
        );
      }
    }

    return checkboxWidget;
  }
}

/// LabeledCheckbox - Checkbox with label for better UX
class LabeledCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final String label;
  final TextStyle? labelStyle;
  final MainAxisAlignment contentAlignment;
  final bool labelPositionLeft;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const LabeledCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    required this.label,
    this.labelStyle,
    this.contentAlignment = MainAxisAlignment.start,
    this.labelPositionLeft = true,
    this.size = 18.0,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final checkboxWidget = Checkbox(
      value: value,
      onChanged: onChanged,
      disabled: disabled,
      size: size,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
      showLabel: false,
    );

    if (labelPositionLeft) {
      return Row(
        mainAxisAlignment: contentAlignment,
        children: [
          Expanded(
            child: Text(
              label,
              style: labelStyle ?? Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          checkboxWidget,
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          checkboxWidget,
          const SizedBox(height: 4),
          Text(
            label,
            style: labelStyle ?? Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }
  }
}

/// CustomCheckbox - Checkbox with custom check mark widget
class CustomCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final Widget? checkWidget;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? activeBorderColor;
  final Color? inactiveBorderColor;
  final double size;
  final double borderWidth;
  final BorderRadius? borderRadius;
  final Duration duration;

  const CustomCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.checkWidget,
    this.activeColor,
    this.inactiveColor,
    this.activeBorderColor,
    this.inactiveBorderColor,
    this.size = 18.0,
    this.borderWidth = 2.0,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<CustomCheckbox> createState() => _CustomCheckboxState();
}

class _CustomCheckboxState extends State<CustomCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.value) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CustomCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.disabled) return;
    widget.onChanged?.call(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveActiveColor = widget.activeColor ??
        theme.colorScheme.primary;
    final effectiveInactiveColor = widget.inactiveColor ??
        theme.colorScheme.surface;
    final effectiveActiveBorderColor = widget.activeBorderColor ??
        effectiveActiveColor;
    final effectiveInactiveBorderColor = widget.inactiveBorderColor ??
        theme.colorScheme.outline;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.value
                  ? effectiveActiveColor
                  : effectiveInactiveColor,
              border: Border.all(
                color: widget.value
                    ? effectiveActiveBorderColor
                    : effectiveInactiveBorderColor,
                width: widget.borderWidth,
              ),
              borderRadius: widget.borderRadius ?? BorderRadius.circular(3.0),
            ),
            child: widget.value
                ? widget.checkWidget ??
                    Icon(
                      Icons.check,
                      size: widget.size * 0.7,
                      color: Colors.white,
                    )
                : null,
          );
        },
      ),
    );
  }
}
