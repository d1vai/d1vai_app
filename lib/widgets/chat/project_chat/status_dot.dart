import 'package:flutter/material.dart';

class ProjectChatStatusDot extends StatefulWidget {
  final Color color;
  final double size;
  final String? tooltip;
  final bool enablePulse;

  const ProjectChatStatusDot({
    super.key,
    required this.color,
    this.size = 12,
    this.tooltip,
    this.enablePulse = true,
  });

  @override
  State<ProjectChatStatusDot> createState() => _ProjectChatStatusDotState();
}

class _ProjectChatStatusDotState extends State<ProjectChatStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.enablePulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ProjectChatStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enablePulse != widget.enablePulse) {
      if (widget.enablePulse) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = widget.enablePulse ? _controller.value : 1.0;
          final scale = widget.enablePulse ? (0.86 + 0.14 * t) : 1.0;
          final opacity = widget.enablePulse ? (0.55 + 0.45 * t) : 1.0;
          return Opacity(
            opacity: opacity,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );

    final tip = widget.tooltip?.trim() ?? '';
    if (tip.isEmpty) return dot;

    return Tooltip(
      message: tip,
      triggerMode: TooltipTriggerMode.longPress,
      child: dot,
    );
  }
}
