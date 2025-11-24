import 'dart:async';
import 'package:flutter/material.dart';

enum TooltipPosition {
  top,
  bottom,
  left,
  right,
}

class TooltipWidget extends StatefulWidget {
  final Widget child;
  final String message;
  final TooltipPosition position;
  final Duration showDuration;
  final Duration hideDuration;
  final Duration delay;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final double? borderRadius;
  final double? elevation;
  final TextStyle? textStyle;
  final bool preferBelow;

  const TooltipWidget({
    super.key,
    required this.child,
    required this.message,
    this.position = TooltipPosition.top,
    this.showDuration = const Duration(milliseconds: 200),
    this.hideDuration = const Duration(milliseconds: 200),
    this.delay = const Duration(milliseconds: 500),
    this.padding,
    this.margin,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.borderRadius,
    this.elevation,
    this.textStyle,
    this.preferBelow = true,
  });

  @override
  State<TooltipWidget> createState() => _TooltipWidgetState();
}

class _TooltipWidgetState extends State<TooltipWidget>
    with SingleTickerProviderStateMixin {
  late OverlayEntry _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isVisible = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.showDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _showTooltip() {
    if (_isVisible) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: GestureDetector(
          onTap: _hideTooltip,
          child: CompositedTransformFollower(
            showWhenUnlinked: false,
            link: _layerLink,
            child: _buildTooltip(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry);
    setState(() {
      _isVisible = true;
    });
    _animationController.forward();
  }

  void _hideTooltip() {
    if (!_isVisible) return;

    _animationController.reverse().then((_) {
      _removeOverlay();
      setState(() {
        _isVisible = false;
      });
    });
  }

  void _removeOverlay() {
    _overlayEntry.remove();
    _overlayEntry.dispose();
  }

  Widget _buildTooltip() {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.9);
    final textColor = widget.textColor ?? theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: widget.margin ?? const EdgeInsets.all(8),
              padding: widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: widget.elevation ?? 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildTooltipContent(textColor),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTooltipContent(Color textColor) {
    final List<Widget> children = [
      Flexible(
        child: Text(
          widget.message,
          style: widget.textStyle ??
              TextStyle(
                color: textColor,
                fontSize: widget.fontSize ?? 12,
                fontWeight: FontWeight.w500,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    ];

    // Add arrow based on position
    switch (widget.position) {
      case TooltipPosition.top:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildArrow(),
            const SizedBox(height: 4),
            ...children,
          ],
        );
      case TooltipPosition.bottom:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...children,
            const SizedBox(height: 4),
            _buildArrow(isInverted: true),
          ],
        );
      case TooltipPosition.left:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildArrow(isHorizontal: true),
            const SizedBox(width: 4),
            ...children,
          ],
        );
      case TooltipPosition.right:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...children,
            const SizedBox(width: 4),
            _buildArrow(isHorizontal: true, isInverted: true),
          ],
        );
    }
  }

  Widget _buildArrow({bool isInverted = false, bool isHorizontal = false}) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.9);

    if (isHorizontal) {
      return Transform.rotate(
        angle: isInverted ? -3.14159 / 2 : 3.14159 / 2,
        child: CustomPaint(
          size: const Size(8, 4),
          painter: _ArrowPainter(bgColor),
        ),
      );
    }

    return Transform.rotate(
      angle: isInverted ? 3.14159 : 0,
      child: CustomPaint(
        size: const Size(8, 4),
        painter: _ArrowPainter(bgColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onLongPress: () {
          _timer?.cancel();
          _timer = Timer(widget.delay, () {
            if (mounted) {
              _showTooltip();
            }
          });
        },
        onLongPressEnd: (_) {
          _timer?.cancel();
        },
        onLongPressCancel: () {
          _timer?.cancel();
        },
        child: MouseRegion(
          onEnter: (_) {
            _timer?.cancel();
            _timer = Timer(widget.delay, () {
              if (mounted) {
                _showTooltip();
              }
            });
          },
          onExit: (_) {
            _timer?.cancel();
            _hideTooltip();
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple tooltip wrapper using Flutter's built-in Tooltip
class SimpleTooltip extends StatelessWidget {
  final Widget child;
  final String message;
  final Duration? showDuration;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final bool preferBelow;

  const SimpleTooltip({
    super.key,
    required this.child,
    required this.message,
    this.showDuration,
    this.padding,
    this.textStyle,
    this.preferBelow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      showDuration: showDuration,
      padding: padding,
      textStyle: textStyle,
      preferBelow: preferBelow,
      child: child,
    );
  }
}
