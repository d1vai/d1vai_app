import 'package:flutter/material.dart';

/// Skeleton widget for loading states
///
/// A shimmer-loading effect that mimics content while data is being fetched
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 4.0,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = widget.baseColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final highlightColor = widget.highlightColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor,
              ],
              stops: [
                0.0,
                _animation.value,
                _animation.value + 0.5,
                _animation.value + 1.0,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Circle-shaped skeleton
class SkeletonCircle extends StatelessWidget {
  final double size;
  final Color? color;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      width: size,
      height: size,
      borderRadius: size / 2,
      baseColor: color,
    );
  }
}

/// Rectangle skeleton with optional height
class SkeletonRectangle extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? color;

  const SkeletonRectangle({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      width: width,
      height: height,
      borderRadius: borderRadius,
      baseColor: color,
    );
  }
}

/// Text line skeleton (multiple lines)
class SkeletonText extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;
  final Color? color;

  const SkeletonText({
    super.key,
    this.lines = 1,
    this.lineHeight = 16,
    this.spacing = 8,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        final width = isLast && lines > 1 ? null : null; // Full width for first lines

        return Padding(
          padding: EdgeInsets.only(bottom: index < lines - 1 ? spacing : 0),
          child: SkeletonRectangle(
            width: width,
            height: lineHeight,
            color: color,
          ),
        );
      }),
    );
  }
}

/// Avatar skeleton (commonly used in lists)
class SkeletonAvatar extends StatelessWidget {
  final double size;

  const SkeletonAvatar({
    super.key,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonCircle(size: size);
  }
}

/// Card skeleton (commonly used for loading cards)
class SkeletonCard extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonCard({
    super.key,
    this.width = double.infinity,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonCircle(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonRectangle(height: 16, width: 120),
                      const SizedBox(height: 8),
                      SkeletonRectangle(height: 14, width: 80),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: [
                  SkeletonText(lines: 3, lineHeight: 14, spacing: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List item skeleton (for list loading states)
class SkeletonListTile extends StatelessWidget {
  final bool hasLeading;
  final bool hasThreeLines;
  final double? contentHeight;

  const SkeletonListTile({
    super.key,
    this.hasLeading = true,
    this.hasThreeLines = false,
    this.contentHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = theme.useMaterial3
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasLeading) ...[
            const SkeletonCircle(size: 40),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonRectangle(height: 16, width: 200),
                const SizedBox(height: 8),
                if (hasThreeLines) ...[
                  SkeletonRectangle(height: 14, width: 160),
                  const SizedBox(height: 6),
                  SkeletonRectangle(height: 14, width: 140),
                ] else
                  SkeletonRectangle(height: 14, width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
