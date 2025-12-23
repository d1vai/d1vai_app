import 'package:flutter/material.dart';

/// Skeleton loader for messages during loading
class MessageSkeleton extends StatefulWidget {
  final int delay;
  final bool isUser;

  const MessageSkeleton({
    super.key,
    this.delay = 0,
    this.isUser = false,
  });

  @override
  State<MessageSkeleton> createState() => _MessageSkeletonState();
}

class _MessageSkeletonState extends State<MessageSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
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

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16.0),
                        topRight: const Radius.circular(16.0),
                        bottomLeft: const Radius.circular(4.0),
                        bottomRight: const Radius.circular(16.0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSkeletonLine(theme, 0.8),
                        const SizedBox(height: 8),
                        _buildSkeletonLine(theme, 0.9),
                        const SizedBox(height: 8),
                        _buildSkeletonLine(theme, 0.6),
                      ],
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

  Widget _buildSkeletonLine(ThemeData theme, double widthFactor) {
    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
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
