import 'package:flutter/material.dart';

class Switch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final double width;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? activeThumbColor;
  final Color? inactiveThumbColor;
  final Color? borderColor;
  final String? label;
  final TextStyle? labelStyle;
  final MainAxisAlignment labelAlignment;
  final bool showLabel;
  final Duration duration;

  const Switch({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.width = 52.0,
    this.height = 32.0,
    this.activeColor,
    this.inactiveColor,
    this.activeThumbColor,
    this.inactiveThumbColor,
    this.borderColor,
    this.label,
    this.labelStyle,
    this.labelAlignment = MainAxisAlignment.spaceBetween,
    this.showLabel = true,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<Switch> createState() => _SwitchState();
}

class _SwitchState extends State<Switch> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late bool _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (_currentValue) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(Switch oldWidget) {
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

    setState(() {
      _currentValue = !_currentValue;
    });

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

    final effectiveActiveColor = widget.activeColor ?? colorScheme.primary;
    final effectiveInactiveColor =
        widget.inactiveColor ?? colorScheme.outline.withValues(alpha: 0.5);
    final effectiveActiveThumbColor =
        widget.activeThumbColor ?? colorScheme.onPrimary;
    final effectiveInactiveThumbColor =
        widget.inactiveThumbColor ?? colorScheme.onSurface;
    final effectiveBorderColor =
        widget.borderColor ?? colorScheme.outline.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: _handleTap,
      child: Focus(
        canRequestFocus: false,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.height / 2),
            color: _currentValue
                ? effectiveActiveColor
                : effectiveInactiveColor,
            border: Border.all(color: effectiveBorderColor, width: 1.0),
          ),
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final position = widget.width - widget.height;
                  final thumbPosition = position * _animation.value;

                  return Positioned(
                    left: thumbPosition,
                    top: (widget.height - (widget.height - 8)) / 2,
                    child: Container(
                      width: widget.height - 8,
                      height: widget.height - 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentValue
                            ? effectiveActiveThumbColor
                            : effectiveInactiveThumbColor,
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// LabeledSwitch - Switch with label for better UX
class LabeledSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final String label;
  final TextStyle? labelStyle;
  final MainAxisAlignment contentAlignment;
  final bool labelPositionLeft;

  const LabeledSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    required this.label,
    this.labelStyle,
    this.contentAlignment = MainAxisAlignment.spaceBetween,
    this.labelPositionLeft = true,
  });

  @override
  Widget build(BuildContext context) {
    final switchWidget = Switch(
      value: value,
      onChanged: onChanged,
      disabled: disabled,
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
          switchWidget,
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switchWidget,
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

/// Custom Switch Builder - For custom styling
class CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;
  final Widget? activeThumb;
  final Widget? inactiveThumb;
  final Color? activeColor;
  final Color? inactiveColor;
  final Widget? activeContent;
  final Widget? inactiveContent;
  final double width;
  final double height;
  final Duration duration;

  const CustomSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.disabled = false,
    this.activeThumb,
    this.inactiveThumb,
    this.activeColor,
    this.inactiveColor,
    this.activeContent,
    this.inactiveContent,
    this.width = 52.0,
    this.height = 32.0,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch>
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
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.value) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CustomSwitch oldWidget) {
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
    final effectiveActiveColor =
        widget.activeColor ?? theme.colorScheme.primary;
    final effectiveInactiveColor =
        widget.inactiveColor ??
        theme.colorScheme.outline.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.height / 2),
          color: widget.value ? effectiveActiveColor : effectiveInactiveColor,
        ),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final position = widget.width - widget.height;
            final thumbPosition = position * _animation.value;

            return Stack(
              children: [
                if (widget.activeContent != null)
                  Positioned.fill(
                    child: widget.value
                        ? widget.activeContent!
                        : const SizedBox.shrink(),
                  ),
                if (widget.inactiveContent != null)
                  Positioned.fill(
                    child: !widget.value
                        ? widget.inactiveContent!
                        : const SizedBox.shrink(),
                  ),
                Positioned(
                  left: thumbPosition,
                  top: (widget.height - (widget.height - 8)) / 2,
                  child: widget.value
                      ? (widget.activeThumb ??
                            Container(
                              width: widget.height - 8,
                              height: widget.height - 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ))
                      : (widget.inactiveThumb ??
                            Container(
                              width: widget.height - 8,
                              height: widget.height - 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.onSurface,
                              ),
                            )),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
