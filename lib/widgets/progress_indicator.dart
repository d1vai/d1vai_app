import 'package:flutter/material.dart';

/// Enhanced Linear Progress Indicator with optional label
class ProgressBar extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final String? label;
  final String? subLabel;
  final double? height;
  final Color? backgroundColor;
  final Color? valueColor;
  final bool showPercentage;
  final Duration animationDuration;
  final TextStyle? labelStyle;
  final TextStyle? percentageStyle;
  final BorderRadius? borderRadius;

  const ProgressBar({
    super.key,
    required this.value,
    this.label,
    this.subLabel,
    this.height,
    this.backgroundColor,
    this.valueColor,
    this.showPercentage = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.labelStyle,
    this.percentageStyle,
    this.borderRadius,
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _animatedValue;

  @override
  void initState() {
    super.initState();
    _animatedValue = widget.value;
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _animation.removeListener(_updateValue);
      _animatedValue = widget.value;
      _controller.reset();
      _controller.forward();
      _animation.addListener(_updateValue);
    }
  }

  void _updateValue() {
    if (mounted) {
      setState(() {
        _animatedValue = _animation.value * widget.value;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        widget.backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final valColor = widget.valueColor ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.label!,
                  style:
                      widget.labelStyle ??
                      TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                ),
              ),
              if (widget.showPercentage)
                Text(
                  '${(_animatedValue * 100).toInt()}%',
                  style:
                      widget.percentageStyle ??
                      TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valColor,
                      ),
                ),
            ],
          ),
          if (widget.subLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.subLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
        Container(
          height: widget.height ?? 8,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _animatedValue.clamp(0.0, 1.0),
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(valColor),
              minHeight: widget.height ?? 8,
            ),
          ),
        ),
      ],
    );
  }
}

/// Enhanced Circular Progress Indicator with center content
class CircularProgress extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double? size;
  final Color? backgroundColor;
  final Color? valueColor;
  final Widget? centerChild;
  final double strokeWidth;

  const CircularProgress({
    super.key,
    required this.value,
    this.size,
    this.backgroundColor,
    this.valueColor,
    this.centerChild,
    this.strokeWidth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valColor = valueColor ?? theme.colorScheme.primary;
    final bgColor =
        backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: bgColor,
            valueColor: AlwaysStoppedAnimation<Color>(valColor),
            strokeWidth: strokeWidth,
          ),
          if (centerChild != null) centerChild!,
        ],
      ),
    );
  }
}

/// Simple circular progress indicator with percentage
class CircularProgressWithPercentage extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double? size;
  final Color? color;
  final TextStyle? textStyle;

  const CircularProgressWithPercentage({
    super.key,
    required this.value,
    this.size,
    this.color,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = color ?? theme.colorScheme.primary;

    return CircularProgress(
      value: value,
      size: size,
      valueColor: progressColor,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.2,
      ),
      centerChild: Text(
        '${(value * 100).toInt()}%',
        style:
            textStyle ??
            TextStyle(
              fontSize: (size ?? 48) * 0.25,
              fontWeight: FontWeight.bold,
              color: progressColor,
            ),
      ),
    );
  }
}

/// Progress indicator with loading text
class LoadingProgress extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final String loadingText;
  final double? height;
  final Color? color;

  const LoadingProgress({
    super.key,
    required this.value,
    required this.loadingText,
    this.height,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressColor = color ?? theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressBar(
          value: value,
          height: height ?? 6,
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
          valueColor: progressColor,
          animationDuration: const Duration(milliseconds: 500),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: null,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              loadingText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Multi-step progress indicator
class StepProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;
  final double? width;
  final Color? activeColor;
  final Color? inactiveColor;

  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
    this.width,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeColor ?? theme.colorScheme.primary;
    final inactive =
        inactiveColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(totalSteps, (index) {
            final isActive = index <= currentStep;
            final isCompleted = index < currentStep;

            return Expanded(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isActive ? active : inactive,
                          shape: BoxShape.circle,
                          border: Border.all(color: active, width: 2),
                        ),
                        child: isCompleted
                            ? Icon(Icons.check, size: 14, color: Colors.white)
                            : Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.white : inactive,
                                  ),
                                ),
                              ),
                      ),
                      if (index < totalSteps - 1)
                        Container(
                          width: width ?? double.infinity,
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: isActive
                              ? active
                              : inactive.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels.map((label) {
            final index = labels.indexOf(label);
            return Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: index <= currentStep
                      ? active
                      : inactive.withValues(alpha: 0.7),
                  fontWeight: index == currentStep
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
