import 'package:flutter/material.dart';

enum SeparatorVariant { solid, dashed, dotted }

/// Separator Widget - A flexible divider component for separating content
class Separator extends StatelessWidget {
  final Axis direction;
  final double thickness;
  final double width;
  final double height;
  final Color? color;
  final double? indent;
  final double? endIndent;
  final SeparatorVariant variant;
  final double? gap;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final EdgeInsetsGeometry? margin;

  const Separator({
    super.key,
    this.direction = Axis.horizontal,
    this.thickness = 1.0,
    this.width = double.infinity,
    this.height = double.infinity,
    this.color,
    this.indent,
    this.endIndent,
    this.variant = SeparatorVariant.solid,
    this.gap,
    this.mainAxisAlignment = MainAxisAlignment.center,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ??
        theme.dividerColor.withValues(alpha: 0.3);

    if (direction == Axis.horizontal) {
      return Container(
        margin: margin,
        child: Divider(
          height: height,
          thickness: thickness,
          color: effectiveColor,
          indent: indent,
          endIndent: endIndent,
        ),
      );
    } else {
      return Container(
        margin: margin,
        child: VerticalDivider(
          width: width,
          thickness: thickness,
          color: effectiveColor,
          indent: indent,
          endIndent: endIndent,
        ),
      );
    }
  }
}

/// CustomSeparator - Separator with custom styling
class CustomSeparator extends StatelessWidget {
  final Axis direction;
  final double thickness;
  final double? width;
  final double? height;
  final Color? color;
  final SeparatorVariant variant;
  final double? gap;
  final List<double>? dashPattern;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double opacity;

  const CustomSeparator({
    super.key,
    this.direction = Axis.horizontal,
    this.thickness = 1.0,
    this.width,
    this.height,
    this.color,
    this.variant = SeparatorVariant.solid,
    this.gap,
    this.dashPattern,
    this.borderRadius,
    this.padding,
    this.margin,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = (color ??
            theme.dividerColor.withValues(alpha: 0.3))
        .withValues(alpha: opacity);

    Widget separator;

    switch (variant) {
      case SeparatorVariant.solid:
        separator = Container(
          width: direction == Axis.horizontal ? width ?? double.infinity : thickness,
          height: direction == Axis.horizontal ? thickness : height ?? double.infinity,
          color: effectiveColor,
        );
        break;

      case SeparatorVariant.dashed:
        separator = _buildDashedSeparator(effectiveColor);
        break;

      case SeparatorVariant.dotted:
        separator = _buildDottedSeparator(effectiveColor);
        break;
    }

    separator = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: separator,
    );

    if (padding != null || margin != null) {
      return Container(
        padding: padding,
        margin: margin,
        child: separator,
      );
    }

    return separator;
  }

  Widget _buildDashedSeparator(Color color) {
    final effectiveGap = gap ?? 4.0;
    final pattern = dashPattern ?? [5.0, 5.0];

    if (direction == Axis.horizontal) {
      return SizedBox(
        height: thickness,
        width: width ?? double.infinity,
        child: CustomPaint(
          painter: _DashedLinePainter(
            color: color,
            strokeWidth: thickness,
            dashWidth: pattern[0],
            dashGap: pattern.length > 1 ? pattern[1] : effectiveGap,
          ),
        ),
      );
    } else {
      return SizedBox(
        width: thickness,
        height: height ?? double.infinity,
        child: CustomPaint(
          painter: _DashedLinePainter(
            color: color,
            strokeWidth: thickness,
            dashWidth: pattern[0],
            dashGap: pattern.length > 1 ? pattern[1] : effectiveGap,
          ),
        ),
      );
    }
  }

  Widget _buildDottedSeparator(Color color) {
    final effectiveGap = gap ?? 2.0;

    if (direction == Axis.horizontal) {
      return SizedBox(
        height: thickness * 2,
        width: width ?? double.infinity,
        child: CustomPaint(
          painter: _DottedLinePainter(
            color: color,
            strokeWidth: thickness,
            dotRadius: thickness,
            dotGap: effectiveGap,
          ),
        ),
      );
    } else {
      return SizedBox(
        width: thickness * 2,
        height: height ?? double.infinity,
        child: CustomPaint(
          painter: _DottedLinePainter(
            color: color,
            strokeWidth: thickness,
            dotRadius: thickness,
            dotGap: effectiveGap,
          ),
        ),
      );
    }
  }
}

/// Vertical Spacer Separator - Separator with text or widget in the middle
class LabeledSeparator extends StatelessWidget {
  final String? label;
  final Widget? child;
  final Axis direction;
  final Color? color;
  final TextStyle? labelStyle;
  final double? thickness;
  final double? indent;
  final double? endIndent;
  final double labelSpacing;

  const LabeledSeparator({
    super.key,
    this.label,
    this.child,
    this.direction = Axis.horizontal,
    this.color,
    this.labelStyle,
    this.thickness,
    this.indent,
    this.endIndent,
    this.labelSpacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.dividerColor.withValues(alpha: 0.3);
    final effectiveLabelStyle = labelStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
        );

    final labelWidget = label != null
        ? Text(
            label!,
            style: effectiveLabelStyle,
          )
        : child ?? const SizedBox.shrink();

    if (direction == Axis.horizontal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Separator(
              direction: Axis.horizontal,
              color: effectiveColor,
              thickness: thickness ?? 1.0,
              indent: indent,
              endIndent: endIndent,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: labelWidget,
          ),
          Expanded(
            child: Separator(
              direction: Axis.horizontal,
              color: effectiveColor,
              thickness: thickness ?? 1.0,
              indent: indent,
              endIndent: endIndent,
            ),
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Separator(
              direction: Axis.vertical,
              color: effectiveColor,
              thickness: thickness ?? 1.0,
              indent: indent,
              endIndent: endIndent,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: labelSpacing),
            child: labelWidget,
          ),
          Expanded(
            child: Separator(
              direction: Axis.vertical,
              color: effectiveColor,
              thickness: thickness ?? 1.0,
              indent: indent,
              endIndent: endIndent,
            ),
          ),
        ],
      );
    }
  }
}

/// Custom painters for dashed and dotted lines
class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  _DashedLinePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double start = 0.0;
    while (start < size.width) {
      final end = start + dashWidth;
      canvas.drawLine(
        Offset(start, size.height / 2),
        Offset(end, size.height / 2),
        paint,
      );
      start = end + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dotRadius;
  final double dotGap;

  _DottedLinePainter({
    required this.color,
    required this.strokeWidth,
    required this.dotRadius,
    required this.dotGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    double start = dotRadius;
    while (start < size.width) {
      canvas.drawCircle(
        Offset(start, size.height / 2),
        dotRadius,
        paint,
      );
      start = dotRadius * 2 + dotGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
