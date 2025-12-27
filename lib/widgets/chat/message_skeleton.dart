import 'package:flutter/material.dart';

/// Skeleton loader for messages during loading
class MessageSkeleton extends StatefulWidget {
  final int delay;
  final bool isUser;
  final bool enableTypingDots;

  const MessageSkeleton({
    super.key,
    this.delay = 0,
    this.isUser = false,
    this.enableTypingDots = true,
  });

  @override
  State<MessageSkeleton> createState() => _MessageSkeletonState();
}

class _MessageSkeletonState extends State<MessageSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -1.2, end: 2.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.isUser;
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_opacityAnimation, _shimmerAnimation]),
      builder: (context, child) {
        final baseBubble = isUser
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest;
        final bubbleBorder = isUser
            ? colorScheme.primary.withValues(alpha: 0.18)
            : colorScheme.outlineVariant.withValues(alpha: 0.55);

        return Opacity(
          opacity: _opacityAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12.0,
                      horizontal: 16.0,
                    ),
                    decoration: BoxDecoration(
                      color: baseBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16.0),
                        topRight: const Radius.circular(16.0),
                        bottomLeft: const Radius.circular(4.0),
                        bottomRight: const Radius.circular(16.0),
                      ),
                      border: Border.all(color: bubbleBorder),
                    ),
                    child: _ShimmerMask(
                      t: _shimmerAnimation.value,
                      base: isUser
                          ? colorScheme.onPrimary.withValues(alpha: 0.18)
                          : colorScheme.onSurface.withValues(alpha: 0.10),
                      highlight: isUser
                          ? colorScheme.onPrimary.withValues(alpha: 0.34)
                          : colorScheme.onSurface.withValues(alpha: 0.20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSkeletonLine(colorScheme, 0.78),
                          const SizedBox(height: 8),
                          _buildSkeletonLine(colorScheme, 0.92),
                          const SizedBox(height: 8),
                          _buildSkeletonLine(colorScheme, 0.56),
                          if (!isUser && widget.enableTypingDots) ...[
                            const SizedBox(height: 10),
                            _TypingDots(
                              t: _controller.value,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonLine(ColorScheme colorScheme, double widthFactor) {
    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _ShimmerMask extends StatelessWidget {
  final double t;
  final Color base;
  final Color highlight;
  final Widget child;

  const _ShimmerMask({
    required this.t,
    required this.base,
    required this.highlight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment(-1, 0),
          end: Alignment(1, 0),
          colors: [
            base,
            base,
            highlight,
            base,
            base,
          ],
          stops: [
            0.0,
            (t - 0.4).clamp(0.0, 1.0),
            t.clamp(0.0, 1.0),
            (t + 0.4).clamp(0.0, 1.0),
            1.0,
          ],
        ).createShader(rect);
      },
      blendMode: BlendMode.srcATop,
      child: child,
    );
  }
}

class _TypingDots extends StatelessWidget {
  final double t;
  final Color color;

  const _TypingDots({required this.t, required this.color});

  @override
  Widget build(BuildContext context) {
    final phase = (t * 3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final local = (phase - i).clamp(0.0, 1.0);
        final eased = Curves.easeInOut.transform(local);
        final y = (1 - eased) * 4;
        final opacity = 0.55 + 0.35 * eased;

        return Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, y),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Loading skeleton list
class MessageSkeletonList extends StatelessWidget {
  final int count;

  const MessageSkeletonList({
    super.key,
    this.count = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (index) {
        // Alternate between user and assistant skeletons
        final isUser = index % 2 == 1;
        return MessageSkeleton(
          delay: index * 100,
          isUser: isUser,
        );
      }),
    );
  }
}
