import 'package:flutter/material.dart';

/// Typing indicator widget showing animated dots
class TypingIndicator extends StatefulWidget {
  final bool isTyping;

  const TypingIndicator({
    super.key,
    this.isTyping = false,
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _animationControllers
        .map((controller) => Tween<double>(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(
                parent: controller,
                curve: Curves.easeInOut,
              ),
            ))
        .toList();

    if (widget.isTyping) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(TypingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTyping != oldWidget.isTyping) {
      if (widget.isTyping) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    for (var i = 0; i < _animationControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted && widget.isTyping) {
          _animationControllers[i].repeat(reverse: true);
        }
      });
    }
  }

  void _stopAnimation() {
    for (final controller in _animationControllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void dispose() {
    for (final controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTyping) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 16.0,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Icon(
              Icons.smart_toy,
              size: 18.0,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
          const SizedBox(width: 8.0),
          // Typing bubble
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
                bottomRight: Radius.circular(16.0),
                bottomLeft: Radius.circular(4.0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _animations[index],
                  builder: (context, child) {
                    return Container(
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 4.0,
                      ),
                      child: Opacity(
                        opacity: _animations[index].value,
                        child: DotWidget(
                          size: 8.0,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual dot widget for typing indicator
class DotWidget extends StatelessWidget {
  final double size;
  final Color color;

  const DotWidget({
    super.key,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
